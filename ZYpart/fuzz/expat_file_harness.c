#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "expat.h"

static void XMLCALL
start_element(void *user_data, const XML_Char *name, const XML_Char **atts) {
  int *depth = (int *)user_data;
  (void)name;
  (void)atts;
  if (depth != NULL && *depth < 1024) {
    *depth += 1;
  }
}

static void XMLCALL
end_element(void *user_data, const XML_Char *name) {
  int *depth = (int *)user_data;
  (void)name;
  if (depth != NULL && *depth > 0) {
    *depth -= 1;
  }
}

static void XMLCALL
character_data(void *user_data, const XML_Char *s, int len) {
  (void)user_data;
  (void)s;
  (void)len;
}

static void
install_handlers(XML_Parser parser, int *depth) {
  XML_SetUserData(parser, depth);
  XML_SetElementHandler(parser, start_element, end_element);
  XML_SetCharacterDataHandler(parser, character_data);
}

static void
parse_input(const uint8_t *data, size_t size, int namespace_mode) {
  int depth = 0;
  XML_Parser parser
      = namespace_mode ? XML_ParserCreateNS(NULL, '!') : XML_ParserCreate(NULL);
  if (parser == NULL) {
    abort();
  }

  install_handlers(parser, &depth);
  XML_SetHashSalt(parser, 0x5a594675UL);
  XML_Parse(parser, (const char *)data, (int)size, XML_TRUE);
  XML_GetCurrentLineNumber(parser);
  XML_GetCurrentColumnNumber(parser);
  XML_ErrorString(XML_GetErrorCode(parser));
  XML_ParserFree(parser);
}

static uint8_t *
read_file(const char *path, size_t *size) {
  FILE *file = fopen(path, "rb");
  uint8_t *buffer;
  long length;

  if (file == NULL) {
    return NULL;
  }
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return NULL;
  }
  length = ftell(file);
  if (length < 0 || length > 1024 * 1024) {
    fclose(file);
    return NULL;
  }
  rewind(file);

  buffer = (uint8_t *)malloc((size_t)length + 1);
  if (buffer == NULL) {
    fclose(file);
    return NULL;
  }
  *size = fread(buffer, 1, (size_t)length, file);
  fclose(file);
  return buffer;
}

int
main(int argc, char **argv) {
  uint8_t *data;
  size_t size = 0;

  if (argc != 2) {
    return 1;
  }

  data = read_file(argv[1], &size);
  if (data == NULL || size == 0) {
    free(data);
    return 0;
  }

  parse_input(data, size, 0);
  parse_input(data, size, 1);
  free(data);
  return 0;
}
