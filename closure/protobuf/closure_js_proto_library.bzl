# Copyright 2016 The Closure Rules Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Utilities for building JavaScript Protocol Buffers.
"""

load("//closure/compiler:closure_js_library.bzl", "closure_js_library")

 
def _js_proto_compile_impl(ctx):
  # Direct sources.
  srcs = depset()
  for src in ctx.attr.srcs:
    srcs += src.files
  srcs = srcs.to_list()

  # All sources: direct + transitive, from dependencies.
  transitive_srcs = depset(srcs)
  for js_proto_library in ctx.attr.deps:
    transitive_srcs += js_proto_library.transitive_srcs
  transitive_srcs = transitive_srcs.to_list()

  js_out_options = [
    "library=" + ctx.label.name
    # TODO: add_require_for_enums, testonly, binary, import_style
  ]
  args = [
    "--js_out=%s:%s" % (",".join(js_out_options), ctx.outputs.library.dirname),
    "--descriptor_set_out=" + ctx.outputs.descriptor.path,
  ]
  args += ["-I" + root for root in _GetWorkspaceRoots(transitive_srcs)]
  args += [src.path for src in srcs]

  ctx.action(
    inputs=transitive_srcs,
    outputs=[ctx.outputs.library, ctx.outputs.descriptor],
    arguments=args,
    progress_message="Generating .js code from .proto %s" % ctx.label.name,
    executable=ctx.executable.protocbin)

  return struct(transitive_srcs=transitive_srcs)


js_proto_compile = rule(
  implementation = _js_proto_compile_impl,
  attrs = {
    "srcs": attr.label_list(allow_files=True),
    "deps": attr.label_list(),
    # TODO:
    # add_require_for_enums
    # testonly
    # binary
    # import_style
    "protocbin": attr.label(
      default=Label("//third_party/protobuf:protoc"),
      executable=True,
      cfg="host"
    ),
  },
  outputs = {
    "library": "%{name}.js",
    "descriptor": "%{name}.descriptor"
  }
)


def closure_js_proto_library(
    name,
    srcs,
    deps = [],
    suppress = [],
    add_require_for_enums = 0,
    testonly = None,
    binary = 1,
    import_style = None,
    protocbin = Label("//third_party/protobuf:protoc"),
    **kwargs):

  js_proto_compile(
    name = name + "_gen",
    srcs = srcs,
    deps = [dep + "_gen" for dep in deps],
    protocbin = protocbin,
    **kwargs
    # TODO:
    # add_require_for_enums
    # testonly
    # binary
    # import_style
  )
  
  closure_js_library(
      name = name,
      srcs = [name + "_gen.js"],
      testonly = testonly,
      deps = deps + [
          str(Label("//closure/library")),
          str(Label("//closure/protobuf:jspb")),
      ],
      internal_descriptors = [name + ".descriptor"],
      suppress = suppress + [
          "analyzerChecks",
          "missingOverride",
          "missingProperties",
          "reportUnknownTypes",
          "unusedLocalVariables",
      ],
      **kwargs
  )


def _GetWorkspaceRoots(files):
  roots = depset()
  for f in files:
    if f.path.startswith('external/'):
      workspace_name_end = f.path.find('/', len('external/'))
      root = f.path[:workspace_name_end]
      if root == 'external/protobuf':
        # TODO: Remove when fixed: github.com/google/protobuf/issues/2598.
        root = 'external/protobuf/src'
      roots += [root]
    else:
      roots += [f.root.path or "."]
  return roots.to_list()

