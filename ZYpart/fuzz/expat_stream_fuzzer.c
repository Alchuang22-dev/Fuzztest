#include <stdint.h>
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

static void XMLCALL
processing_instruction(void *user_data, const XML_Char *target,
                       const XML_Char *data) {
  (void)user_data;
  (void)target;
  (void)data;
}

static void XMLCALL
comment_handler(void *user_data, const XML_Char *data) {
  (void)user_data;
  (void)data;
}

static void XMLCALL
start_cdata(void *user_data) {
  (void)user_data;
}

static void XMLCALL
end_cdata(void *user_data) {
  (void)user_data;
}

static void
install_handlers(XML_Parser parser, int *depth) {
  XML_SetUserData(parser, depth);
  XML_SetElementHandler(parser, start_element, end_element);
  XML_SetCharacterDataHandler(parser, character_data);
  XML_SetProcessingInstructionHandler(parser, processing_instruction);
  XML_SetCommentHandler(parser, comment_handler);
  XML_SetCdataSectionHandler(parser, start_cdata, end_cdata);
}

static void
parse_direct(const uint8_t *data, size_t size, int namespace_mode) {
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

  XML_Parser external = XML_ExternalEntityParserCreate(parser, "fuzz", NULL);
  if (external != NULL) {
    int external_depth = 0;
    install_handlers(external, &external_depth);
    XML_Parse(external, (const char *)data, (int)size, XML_TRUE);
    XML_ParserFree(external);
  }

  XML_ParserFree(parser);
}

static void
parse_buffered(const uint8_t *data, size_t size) {
  int depth = 0;
  XML_Parser parser = XML_ParserCreate(NULL);
  if (parser == NULL) {
    abort();
  }

  install_handlers(parser, &depth);
  XML_SetHashSalt(parser, 0x5a594675UL);
  void *buffer = XML_GetBuffer(parser, (int)size);
  if (buffer != NULL) {
    memcpy(buffer, data, size);
    XML_ParseBuffer(parser, (int)size, XML_TRUE);
  }

  XML_ParserFree(parser);
}

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (data == NULL || size == 0 || size > 1024 * 1024) {
    return 0;
  }

  parse_direct(data, size, 0);
  parse_direct(data, size, 1);
  parse_buffered(data, size);
  return 0;
}
