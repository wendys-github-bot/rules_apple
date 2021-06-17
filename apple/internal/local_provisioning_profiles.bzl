"""
Bazel rules for using locally installed provisioning profiles for debug builds
"""

def _local_provisioning_profiles(repository_ctx):
    repository_ctx.symlink(
        "{}/Library/MobileDevice/Provisioning Profiles".format(repository_ctx.os.environ["HOME"]),
        "profiles",
    )

    repository_ctx.file("BUILD", """
filegroup(
    name = "profiles",
    srcs = glob(["profiles/*.mobileprovision"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "empty",
    srcs = [],
    visibility = ["//visibility:public"],
)

alias(
    name = "fallback_profiles",
    actual = "{}",
    visibility = ["//visibility:public"],
)
""".format(repository_ctx.attr.fallback_profiles or ":empty"))

local_provisioning_profiles = repository_rule(
    environ = ["HOME"],
    local = True,
    implementation = _local_provisioning_profiles,
    attrs = dict(
        fallback_profiles = attr.label(
            allow_files = [".mobileprovision"],
        ),
    ),
)

def _local_provisioning_profile(ctx):
    selected_profile_path = "{name}.mobileprovision".format(name = ctx.label.name)
    selected_profile = ctx.actions.declare_file(selected_profile_path)

    args = ctx.actions.args()
    args.add(ctx.attr.name)
    args.add(selected_profile)
    args.add("--local-profiles")
    args.add_all(ctx.files._local_srcs)
    args.add("--fallback-profiles")
    args.add_all(ctx.files._fallback_srcs)

    ctx.actions.run(
        executable = ctx.executable._finder,
        arguments = [args],
        inputs = ctx.files._local_srcs + ctx.files._fallback_srcs,
        outputs = [selected_profile],
        execution_requirements = {"no-sandbox": "1"},
    )

    return [DefaultInfo(files = depset([selected_profile]))]

local_provisioning_profile = rule(
    attrs = dict(
        _fallback_srcs = attr.label(
            allow_files = [".mobileprovision"],
            default = "@local_provisioning_profiles//:profiles",
        ),
        _local_srcs = attr.label(
            default = "@local_provisioning_profiles//:profiles",
        ),
        _finder = attr.label(
            cfg = "exec",
            default = "@build_bazel_rules_apple//tools/local_provisioning_profile_finder",
            executable = True,
        ),
    ),
    implementation = _local_provisioning_profile,
)
