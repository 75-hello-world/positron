/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "mozilla/ModuleUtils.h"
#include "nsIModule.h"

#include "nsINodeLoader.h"
#include "NodeLoader.h"
#include "nsIFile.h"
#include "nsDirectoryService.h"
#include "nsDirectoryServiceDefs.h"
#include "node.h"
#include "uv.h"
#include "env.h"
#include "jsapi.h"
#include "nsString.h"
#include "nsAppRunner.h"

////////////////////////////////////////////////////////////////////////
// Define the contructor function for the objects
//
// NOTE: This creates an instance of objects by using the default constructor
//
NS_GENERIC_FACTORY_CONSTRUCTOR(NodeLoader)

////////////////////////////////////////////////////////////////////////
// Define a table of CIDs implemented by this module along with other
// information like the function to create an instance, contractid, and
// class name.
//
#define NS_NODELOADER_CONTRACTID \
  "@mozilla.org/positron/nodeloader;1"

#define NS_NODELOADER_CID             \
{ /* 019718E3-CDB5-11d2-8D3C-000000000000 */    \
0x019618e3, 0xcdb5, 0x11d2,                     \
{ 0x8d, 0x3c, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 } }

// static const nsModuleComponentInfo components[] = {
//   { nullptr, NS_NODELOADER_CID, "@mozilla.org/positron/nodeloader;1", NodeLoaderConstructor },
// };


/* Implementation file */
NS_IMPL_ISUPPORTS(NodeLoader, nsINodeLoader)

NodeLoader::NodeLoader()
{
  /* member initializers and constructor code */
}

NodeLoader::~NodeLoader()
{
  /* destructor code */
}

/* void init (); */
NS_IMETHODIMP NodeLoader::Init(JSContext* aContext)
{
  v8::V8::Initialize();
  v8::Isolate* isolate = v8::Isolate::New(js::GetRuntime(aContext));
  // v8::Isolate::Scope isolate_scope(isolate);
  // TODO: FIX THIS LEAK
  v8::Isolate::Scope* isolate_scope = new v8::Isolate::Scope(isolate);
  v8::HandleScope handle_scope(isolate);

  v8::Local<v8::Context> context = v8::Context::New(isolate);
  // v8::Context::Scope context_scope(context);
  // TODO: FIX THIS LEAK
  v8::Context::Scope* context_scope = new v8::Context::Scope(context);

  nsCOMPtr<nsIFile> greDir;
  nsDirectoryService::gService->Get(NS_GRE_DIR,
                                    NS_GET_IID(nsIFile),
                                    getter_AddRefs(greDir));
  MOZ_ASSERT(greDir);
  greDir->AppendNative(NS_LITERAL_CSTRING("modules"));
  greDir->AppendNative(NS_LITERAL_CSTRING("browser"));
  greDir->AppendNative(NS_LITERAL_CSTRING("init.js"));
  nsAutoString path;
  greDir->GetPath(path);

  // XXX There must be some better way to do this, but if the char array isn't
  // copied it seems to get mangled.
  NS_LossyConvertUTF16toASCII asciiPath(path);
  char* copy = new char[asciiPath.Length() + 1];
  strcpy(copy, asciiPath.get());

  int exec_argc;
  const char** exec_argv;
  int argc = 2;
  char **argv = new char *[argc + 1];
  argv[0] = gArgv[0];
  argv[1] = copy;
  node::Init(&argc, const_cast<const char**>(argv),  &exec_argc, &exec_argv);

  node::Environment* env = node::CreateEnvironment(
    isolate,
    uv_default_loop(),
    context,
    argc, argv, 0, nullptr);

  env->process_object()->Set(v8::String::NewFromUtf8(isolate, "resourcesPath"), v8::String::NewFromUtf8(isolate, gArgv[1]));
  env->process_object()->Set(v8::String::NewFromUtf8(isolate, "type"), v8::String::NewFromUtf8(isolate, "browser"));

  node::LoadEnvironment(env);

  return NS_OK;
}

NS_DEFINE_NAMED_CID(NS_NODELOADER_CID);

static const mozilla::Module::CIDEntry kEmbeddingCIDs[] = {
    { &kNS_NODELOADER_CID, false, nullptr, NodeLoaderConstructor },
    { nullptr }
};

static const mozilla::Module::ContractIDEntry kEmbeddingContracts[] = {
    { NS_NODELOADER_CONTRACTID, &kNS_NODELOADER_CID },
    { nullptr }
};

static const mozilla::Module kEmbeddingModule = {
    mozilla::Module::kVersion,
    kEmbeddingCIDs,
    kEmbeddingContracts
};

NSMODULE_DEFN(NodeLoader) = &kEmbeddingModule;