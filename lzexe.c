/* Linux-hosted, format-compatible LZEXE 0.91 packer. */
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "build/exepack.h"

enum {
  HEADER = 32,
  WINDOW = 8192,
  LENMAX = 253,
  NIL = WINDOW,
  ROOT = WINDOW + 1,
  ROOTS = 4096,
  RELOCMAX = 16000
};

struct bytes {
  uint8_t *p;
  size_t n, cap;
};
struct lz {
  uint8_t text[WINDOW + LENMAX + 1];
  uint16_t rson[ROOT + ROOTS];
  uint16_t dad[WINDOW + 1];
  uint16_t match_len, match_pos, match_npos;
  uint16_t segsize, ecartmax;
  int16_t ecart;
  struct bytes out;
  uint16_t mask, codeword;
  uint8_t code[130];
  size_t code_n;
};

struct mz_header {
  uint16_t bytes_in_last_page;
  uint16_t page_count;
  uint16_t relocation_count;
  uint16_t header_paragraphs;
  uint16_t minimum_allocation;
  uint16_t maximum_allocation;
  uint16_t initial_ss;
  uint16_t initial_sp;
  uint16_t initial_ip;
  uint16_t initial_cs;
  uint16_t relocation_offset;
};

static void die(const char *s) {
  fprintf(stderr, "lzexe: %s\n", s);
  exit(1);
}
static uint16_t rd16(const uint8_t *p) {
  return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}
static void wr16(uint8_t *p, uint16_t x) {
  p[0] = x;
  p[1] = x >> 8;
}
static void grow(struct bytes *b, size_t more) {
  if (more <= b->cap - b->n)
    return;
  size_t cap = b->cap ? b->cap : 4096;
  while (more > cap - b->n)
    cap *= 2;
  uint8_t *p = realloc(b->p, cap);
  if (!p)
    die("out of memory");
  b->p = p;
  b->cap = cap;
}
static void put(struct bytes *b, uint8_t x) {
  grow(b, 1);
  b->p[b->n++] = x;
}
static void putn(struct bytes *b, const void *p, size_t n) {
  grow(b, n);
  memcpy(b->p + b->n, p, n);
  b->n += n;
}
static void put16(struct bytes *b, uint16_t x) {
  put(b, x);
  put(b, x >> 8);
}

static void flush_code(struct lz *z) {
  put16(&z->out, z->codeword);
  putn(&z->out, z->code + 2, z->code_n - 2);
  z->ecart = (int16_t)((uint16_t)z->ecart + z->code_n);
  z->mask = 1;
  z->codeword = 0;
  z->code_n = 2;
}
static void putbit(struct lz *z, unsigned bit) {
  if (bit)
    z->codeword |= z->mask;
  z->mask <<= 1;
  if (!z->mask)
    flush_code(z);
}
static void putch(struct lz *z, uint8_t x) { z->code[z->code_n++] = x; }

static void insert_node(struct lz *z, uint16_t r) {
  uint16_t root =
      ROOT +
      (((uint16_t)z->text[r] | ((uint16_t)z->text[r + 1] << 8)) & 0x0fff);
  z->rson[r] = z->rson[root];
  z->dad[z->rson[root]] = root;
  z->rson[root] = r;
  z->dad[r] = root;
}
static void test_match(struct lz *z, uint16_t r) {
  uint16_t root =
      ROOT +
      (((uint16_t)z->text[r] | ((uint16_t)z->text[r + 1] << 8)) & 0x0fff);
  uint16_t node = z->rson[root], best_left = LENMAX - 1, best = 0;
  while (node != NIL) {
    unsigned i;
    for (i = 1; i < LENMAX; ++i)
      if (z->text[node + i] != z->text[r + i])
        break;
    if (i == LENMAX) {
      best = node;
      best_left = 0xffff;
      break;
    }
    uint16_t left = i == LENMAX ? 0xffff : (uint16_t)(LENMAX - 1 - i);
    if (left < best_left) {
      best = node;
      best_left = left;
    } else if (left >= best_left) {
      node = z->rson[node];
      continue;
    }
    node = z->rson[node];
  }
  z->match_len = (uint16_t)(LENMAX - best_left - 1);
  z->match_pos = (uint16_t)((r - best) & (WINDOW - 1));
  z->match_npos = (uint16_t)-z->match_pos;
  z->rson[r] = z->rson[root];
  z->dad[z->rson[root]] = root;
  z->rson[root] = r;
  z->dad[r] = root;
}
static void delete_node(struct lz *z, uint16_t p) {
  uint16_t parent = z->dad[p];
  if (parent != NIL) {
    z->rson[parent] = NIL;
    z->dad[p] = NIL;
  }
}
static void token(struct lz *z, uint16_t len, uint16_t pos, uint16_t npos,
                  uint8_t literal) {
  if (len < 2 || (len == 2 && pos >= 256)) {
    z->match_len = 1;
    putbit(z, 1);
    putch(z, literal);
    return;
  }
  putbit(z, 0);
  if (len <= 5 && pos < 256) {
    uint16_t v = len - 2;
    putbit(z, 0);
    putbit(z, v & 2);
    putbit(z, v & 1);
    putch(z, npos);
  } else {
    putbit(z, 1);
    putch(z, npos);
    putch(z, (uint8_t)((npos >> 8 << 3) | (len <= 9 ? len - 2 : 0)));
    if (len > 9)
      putch(z, len - 1);
  }
}
static void segment_marker(struct lz *z) {
  putbit(z, 0);
  putbit(z, 1);
  putch(z, 0);
  putch(z, 0xf0);
  putch(z, 1);
}
static struct bytes lz_compress(const uint8_t *in, size_t n,
                                uint16_t *ecartmax) {
  struct lz z;
  memset(&z, 0, sizeof z);
  for (size_t i = 0; i < ROOT + ROOTS; ++i)
    z.rson[i] = NIL;
  for (size_t i = 0; i <= WINDOW; ++i)
    z.dad[i] = NIL;
  z.mask = 1;
  z.code_n = 2;
  size_t input = 0, lenrest = n < LENMAX ? n : LENMAX;
  uint16_t si = 0, di = WINDOW - LENMAX;
  for (size_t i = 0; i < lenrest; ++i)
    z.text[di + i] = in[input++];
  z.text[di + lenrest] = 0;
  test_match(&z, di);
  while (lenrest) {
    uint16_t len = z.match_len;
    if (len > lenrest)
      z.match_len = len = (uint16_t)lenrest;
    token(&z, len, z.match_pos, z.match_npos, z.text[di]);
    len = z.match_len;
    int16_t value = (int16_t)((uint16_t)z.ecart - len);
    while (value < 0) {
      ++z.ecartmax;
      value = (int16_t)((uint16_t)value + 16);
    }
    z.ecart = value;
    z.segsize = (uint16_t)(z.segsize + len);
    if (z.segsize >= 0xa000) {
      segment_marker(&z);
      z.segsize = 0;
    }
    while (len--) {
      delete_node(&z, si);
      if (input < n) {
        uint8_t c = in[input++];
        z.text[si] = c;
        if (si < LENMAX - 1)
          z.text[si + WINDOW] = c;
      } else
        --lenrest;
      si = (si + 1) & (WINDOW - 1);
      di = (di + 1) & (WINDOW - 1);
      if (len)
        insert_node(&z, di);
    }
    test_match(&z, di);
  }
  putbit(&z, 0);
  putbit(&z, 1);
  putch(&z, 0);
  putch(&z, 0xf0);
  putch(&z, 0);
  flush_code(&z);
  *ecartmax = z.ecartmax;
  return z.out;
}

/* MZ executable input and output. */
static int compare_u32(const void *left, const void *right) {
  uint32_t a = *(const uint32_t *)left;
  uint32_t b = *(const uint32_t *)right;
  return (a > b) - (a < b);
}

static struct bytes read_file(const char *name) {
  FILE *f = fopen(name, "rb");
  struct bytes b = {0};
  uint8_t buf[8192];

  if (!f)
    die(strerror(errno));

  for (;;) {
    size_t n = fread(buf, 1, sizeof buf, f);
    putn(&b, buf, n);
    if (n < sizeof buf)
      break;
  }
  if (ferror(f))
    die("read failed");
  fclose(f);
  return b;
}

static void write_file(const char *name, const struct bytes *b) {
  FILE *f = fopen(name, "wb");

  if (!f)
    die(strerror(errno));
  if (fwrite(b->p, 1, b->n, f) != b->n || fclose(f))
    die("write failed");
}

static struct mz_header read_mz_header(const struct bytes *file) {
  struct mz_header header;

  if (file->n < HEADER || rd16(file->p) != 0x5a4d)
    die("not an MZ executable");
  header.bytes_in_last_page = rd16(file->p + 2);
  header.page_count = rd16(file->p + 4);
  header.relocation_count = rd16(file->p + 6);
  header.header_paragraphs = rd16(file->p + 8);
  header.minimum_allocation = rd16(file->p + 10);
  header.maximum_allocation = rd16(file->p + 12);
  header.initial_ss = rd16(file->p + 14);
  header.initial_sp = rd16(file->p + 16);
  header.initial_ip = rd16(file->p + 20);
  header.initial_cs = rd16(file->p + 22);
  header.relocation_offset = rd16(file->p + 24);
  return header;
}

static size_t declared_file_size(const struct mz_header *header) {
  size_t full_pages = header->page_count ? header->page_count - 1 : 0;
  size_t final_page =
      header->bytes_in_last_page ? header->bytes_in_last_page : 512;
  return full_pages * 512 + final_page;
}

static uint32_t *read_relocations(const struct bytes *file,
                                  const struct mz_header *header) {
  uint32_t *relocations;

  if (header->relocation_count > RELOCMAX ||
      (size_t)header->relocation_offset + 4u * header->relocation_count >
          file->n) {
    die("unsupported or malformed MZ executable");
  }
  relocations = malloc((size_t)header->relocation_count * sizeof *relocations);
  if (header->relocation_count && !relocations)
    die("out of memory");

  for (uint16_t i = 0; i < header->relocation_count; ++i) {
    const uint8_t *entry = file->p + header->relocation_offset + 4u * i;
    relocations[i] = rd16(entry) + ((uint32_t)rd16(entry + 2) << 4);
  }
  qsort(relocations, header->relocation_count, sizeof *relocations,
        compare_u32);
  return relocations;
}

static void write_compressed_relocations(struct bytes *output,
                                         const uint32_t *relocations,
                                         uint16_t count) {
  uint32_t previous = 0;

  for (uint16_t i = 0; i < count; ++i) {
    while (relocations[i] - previous > 0xfff0) {
      put(output, 0);
      put16(output, 0);
      previous += 0xfff0;
    }

    uint32_t delta = relocations[i] - previous;
    if (delta <= 255)
      put(output, delta);
    else {
      put(output, 0);
      put16(output, delta);
    }
    previous = relocations[i];
  }

  put(output, 0);
  put16(output, 1);
}

static void write_output_header(struct bytes *output,
                                const struct mz_header *input,
                                size_t packed_size, uint16_t ecartmax,
                                size_t private_header_offset) {
  uint16_t packed_paragraphs = (packed_size + 15) / 16;
  uint16_t private_size = (uint16_t)(output->n - private_header_offset);
  uint16_t private_paragraphs = (private_size + 15) / 16;
  uint16_t shift = ecartmax + 16;
  uint16_t extra_paragraphs = shift + private_paragraphs + 9;

  wr16(output->p + 0, 0x5a4d);
  wr16(output->p + 2, output->n % 512);
  wr16(output->p + 4, (output->n + 511) / 512);
  wr16(output->p + 6, 0);
  wr16(output->p + 8, 2);
  wr16(output->p + 10, input->minimum_allocation + extra_paragraphs);
  wr16(output->p + 12, input->maximum_allocation > 0xffff - extra_paragraphs
                           ? 0xffff
                           : input->maximum_allocation + extra_paragraphs);
  wr16(output->p + 14, packed_paragraphs + shift + private_paragraphs);
  wr16(output->p + 16, 0x0080);
  wr16(output->p + 20, 0x000e);
  wr16(output->p + 22, packed_paragraphs);
  wr16(output->p + 24, 0x001c);
  wr16(output->p + 28, 0x5a4c);
  wr16(output->p + 30, 0x3139);

  wr16(output->p + private_header_offset + 0, input->initial_ip);
  wr16(output->p + private_header_offset + 2, input->initial_cs);
  wr16(output->p + private_header_offset + 4, input->initial_sp);
  wr16(output->p + private_header_offset + 6, input->initial_ss);
  wr16(output->p + private_header_offset + 8, packed_paragraphs);
  wr16(output->p + private_header_offset + 10, shift);
  wr16(output->p + private_header_offset + 12, private_size);
}

int main(int argc, char **argv) {
  if (argc != 3)
    die("usage: lzexe INPUT.EXE OUTPUT.EXE");

  printf("LZEXE Linux C port\n\n");
  printf("Packing %s\n", argv[1]);
  printf("Reading MZ header...\n");
  struct bytes input_file = read_file(argv[1]);
  struct mz_header input_header = read_mz_header(&input_file);
  size_t input_size = declared_file_size(&input_header);
  size_t image_offset = (size_t)input_header.header_paragraphs * 16;

  if (input_size > input_file.n || image_offset > input_size)
    die("unsupported or malformed MZ executable");

  printf("Reading relocation table...\n");
  uint32_t *relocations = read_relocations(&input_file, &input_header);
  uint16_t ecartmax;
  printf("Compressing executable image...\n");
  struct bytes packed_image = lz_compress(input_file.p + image_offset,
                                          input_size - image_offset, &ecartmax);
  struct bytes output_file = {0};
  uint8_t empty_header[HEADER] = {0};

  putn(&output_file, empty_header, sizeof empty_header);
  putn(&output_file, packed_image.p, packed_image.n);
  while (output_file.n & 15)
    put(&output_file, 0);

  size_t private_header_offset = output_file.n;
  uint8_t empty_private_header[14] = {0};
  printf("Writing 8086 decompressor...\n");
  putn(&output_file, empty_private_header, sizeof empty_private_header);
  putn(&output_file, exepack, exepack_len);
  printf("Writing compressed relocation table...\n");
  write_compressed_relocations(&output_file, relocations,
                               input_header.relocation_count);
  printf("Writing MZ header...\n");
  write_output_header(&output_file, &input_header, packed_image.n, ecartmax,
                      private_header_offset);
  write_file(argv[2], &output_file);

  double reduction = input_file.n
      ? 100.0 * (1.0 - (double)output_file.n / input_file.n)
      : 0.0;
  printf("\nDone: %zu -> %zu bytes (%.2f%% reduction)\n", input_file.n,
         output_file.n, reduction);

  free(relocations);
  free(input_file.p);
  free(packed_image.p);
  free(output_file.p);
  return 0;
}
