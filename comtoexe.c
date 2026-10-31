/* Linux-hosted COM-to-MZ-EXE converter compatible with COMTOEXE 1.01. */
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
    MZ_HEADER_SIZE = 32,
    COPY_BUFFER_SIZE = 32768,
    MAX_COM_SIZE = 65535,
};

static void die(const char *message) {
    fprintf(stderr, "comtoexe: %s\n", message);
    exit(1);
}

static void write_u16le(uint8_t *bytes, uint16_t value) {
    bytes[0] = value;
    bytes[1] = value >> 8;
}

static char *duplicate(const char *text) {
    size_t size = strlen(text) + 1;
    char *result = malloc(size);
    if (result) memcpy(result, text, size);
    return result;
}

static int has_extension(const char *name) {
    return strrchr(name, '.') != NULL;
}

static char *add_extension(const char *name, const char *extension) {
    size_t name_length = strlen(name);
    size_t extension_length = strlen(extension);
    char *result = malloc(name_length + 1 + extension_length + 1);

    if (!result) die("out of memory");
    memcpy(result, name, name_length);
    result[name_length] = '.';
    memcpy(result + name_length + 1, extension, extension_length + 1);
    return result;
}

static char *replace_extension(const char *name, const char *extension) {
    const char *dot = strrchr(name, '.');
    size_t prefix_length = dot ? (size_t)(dot - name + 1) : strlen(name) + 1;
    size_t extension_length = strlen(extension);
    char *result = malloc(prefix_length + extension_length + 1);

    if (!result) die("out of memory");
    memcpy(result, name, prefix_length);
    if (!dot) result[prefix_length - 1] = '.';
    memcpy(result + prefix_length, extension, extension_length + 1);
    return result;
}

static long file_size(FILE *file) {
    if (fseek(file, 0, SEEK_END) || ftell(file) < 0) die("cannot determine input size");
    long size = ftell(file);
    if (fseek(file, 0, SEEK_SET)) die("cannot seek input");
    return size;
}

static void make_mz_header(uint8_t header[MZ_HEADER_SIZE], long com_size) {
    uint32_t exe_size = (uint32_t)com_size + MZ_HEADER_SIZE;

    memset(header, 0, MZ_HEADER_SIZE);
    write_u16le(header + 0, 0x5a4d);                          /* MZ signature */
    write_u16le(header + 2, exe_size % 512);                  /* bytes in last page */
    write_u16le(header + 4, (exe_size + 511) / 512);          /* page count */
    write_u16le(header + 8, 2);                               /* header paragraphs */
    write_u16le(header + 10, 0x1000 - ((com_size + 15) / 16));/* minimum allocation */
    write_u16le(header + 12, 0xffff);                         /* maximum allocation */
    write_u16le(header + 14, 0xfff0);                         /* initial SS */
    write_u16le(header + 16, 0xfffe);                         /* initial SP */
    write_u16le(header + 20, 0x0100);                         /* initial IP */
    write_u16le(header + 22, 0xfff0);                         /* initial CS */
    write_u16le(header + 24, 0x001c);                         /* relocation table */
}

static void copy_remaining(FILE *input, FILE *output) {
    uint8_t buffer[COPY_BUFFER_SIZE];

    for (;;) {
        size_t count = fread(buffer, 1, sizeof buffer, input);
        if (count && fwrite(buffer, 1, count, output) != count) die("cannot write output");
        if (count < sizeof buffer) break;
    }
    if (ferror(input)) die("cannot read input");
}

int main(int argc, char **argv) {
    if (argc < 2 || argc > 3) die("usage: comtoexe INPUT[.COM] [OUTPUT[.EXE]]");
    char *input_name = has_extension(argv[1]) ? duplicate(argv[1]) : add_extension(argv[1], "COM");
    char *output_name = argc == 3
        ? (has_extension(argv[2]) ? duplicate(argv[2]) : add_extension(argv[2], "EXE"))
        : replace_extension(input_name, "EXE");
    if (!input_name || !output_name) die("out of memory");
    FILE *input = fopen(input_name, "rb");
    if (!input) die(strerror(errno));
    long com_size = file_size(input);
    if (com_size > MAX_COM_SIZE) die("COM file is longer than 65535 bytes");

    uint8_t first_bytes[2] = {0, 0};
    size_t first_byte_count = fread(first_bytes, 1, sizeof first_bytes, input);
    if (ferror(input)) die("cannot read input");
    if (first_byte_count == 2 && first_bytes[0] == 'M' && first_bytes[1] == 'Z') die("input appears to be an EXE file");

    FILE *output = fopen(output_name, "wb");
    if (!output) die(strerror(errno));
    uint8_t header[MZ_HEADER_SIZE];
    make_mz_header(header, com_size);
    if (fwrite(header, 1, sizeof header, output) != sizeof header ||
        fwrite(first_bytes, 1, first_byte_count, output) != first_byte_count) die("cannot write output");
    copy_remaining(input, output);

    int input_error = fclose(input);
    int output_error = fclose(output);
    if (input_error || output_error) die("I/O error");
    free(input_name);
    free(output_name);
    return 0;
}
