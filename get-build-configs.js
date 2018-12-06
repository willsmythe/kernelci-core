//
// Calculate the set of configs to build (ported from jenkins/build-trigger.jpl)
//
// Parameters (via environment variables):
//
//  TREE
//    URL of the kernel Git repository
//  TREE_NAME
//    Name of the kernel Git repository (tree)
//  BRANCH
//    Name of the kernel branch within the tree
//  ARCH_LIST (x86 arm64 arm mips arc riscv)
//    List of CPU architectures to build
//  PUBLISH (boolean)
//    Publish build results via the KernelCI backend API
//  EMAIL (boolean)
//    Send build results via email
//

const fs = require('fs');
const os = require('os');
const process = require('process');
const execSync = require('child_process').execSync;

const params = process.env;

function addDefconfigs(configs, kdir, arch) {
    const configs_dir = `${kdir}/arch/${arch}/configs`

    if (fs.existsSync(configs_dir)) {
        let found = execSync('ls -1 *defconfig || echo -n', { cwd: configs_dir/*, stdio: ['pipe', 'pipe', 'ignore']*/ }).toString().trim().split(os.EOL);

        found.forEach(config => configs.add(config));

        if (arch == "mips") {
            configs.delete("generic_defconfig");
        }

        if (arch == "arc") {
            // remove any non ARCv2 defconfigs since we only have ARCv2 toolchain
            let found = execSync('grep -L CONFIG_ISA_ARCV2 *defconfig || echo -n', { cwd: configs_dir, stdio: ['pipe', 'pipe', 'ignore'] }).toString().trim().split(os.EOL);
            found.forEach(config => configs.delete(config));
        }

	    // also remove "nsim_hs_defconfig" since this will be base_defconfig later
	    configs.delete("nsim_hs_defconfig");
    } else {
        //console.log(`WARNING: No configs directory: ${configs_dir}`);
    }

    if (fs.existsSync(`${kdir}/kernel/configs/tiny.config`)) {
        configs.add('tinyconfig');
    }
}

function addExtraIfExists(extra, kdir, path) {
    if (fs.existsSync(`${kdir}/${path}`)) {
        extra.push(path);
    }
}

function addExtraConfigs(configs, kdir, arch) {
    let configs_dir = `${kdir}/arch/${arch}/configs`;
    let base_defconfig = "defconfig";
    let extra = [];

    if (arch == "arc") {
        // default "defconfig" is not ARCv2, and we only have ARCv2 toolchain
        base_defconfig = "nsim_hs_defconfig";
    }

    if (arch == "arm") {
        base_defconfig = "multi_v7_defconfig";

        extra = [
            "CONFIG_CPU_BIG_ENDIAN=y",
            "CONFIG_SMP=n",
            "CONFIG_EFI=y+CONFIG_ARM_LPAE=y",
        ];

        if (fs.existsSync(`${configs_dir}/mvebu_v7_defconfig`))
            configs.add("mvebu_v7_defconfig+CONFIG_CPU_BIG_ENDIAN=y");

        if (params.TREE_NAME == "next")
            configs.add("allmodconfig");

        if (params.TREE_NAME == "ardb" && params.BRANCH == "arm-kaslr-latest"){
            extra.push("CONFIG_RANDOMIZE_BASE=y");
            extra.push("CONFIG_THUMB2_KERNEL=y+CONFIG_RANDOMIZE_BASE=y");
            configs.add("multi_v5_defconfig");
            configs.add("omap2plus_defconfig+CONFIG_RANDOMIZE_BASE=y");
            configs.add("omap2plus_defconfig");
        }
    } else if (arch == "arm64") {
        configs.add("allmodconfig");

        extra = [
            "CONFIG_CPU_BIG_ENDIAN=y",
            "CONFIG_RANDOMIZE_BASE=y",
        ];
    } else if (arch == "x86") {
        configs.add("allmodconfig");
        addExtraIfExists(extra, kdir, "arch/x86/configs/kvm_guest.config");
    }

    ["debug", "kselftest"].forEach(frag => {
        addExtraIfExists(extra, kdir, `kernel/configs/${frag}.config`);
    });

    if (params.TREE_NAME == "lsk" || params.TREE_NAME == "anders") {
        let frags = "linaro/configs/kvm-guest.conf";

        /* For -rt kernels, build with RT fragment */
        let rt_frag = "kernel/configs/preempt-rt.config";

        if (!fs.existsSync(`${kdir}/${rt_frag}`))
            rt_frag = "linaro/configs/preempt-rt.conf";

        /*TODO 
        def has_preempt_rt_full = sh(
            returnStatus: true,
            script: "grep -q \"config PREEMPT_RT_FULL\" ${kdir}/kernel/Kconfig.preempt")

        if (has_preempt_rt_full)
            extra.add(rt_frag)*/

        if (arch == "arm") {
            let kvm_host_frag = "linaro/configs/kvm-host.conf";
            if (fs.existsSync(`${kdir}/${kvm_host_frag}`)) {
                let lpae_base = "multi_v7_defconfig+CONFIG_ARM_LPAE=y"
                configs.add(`${lpae_base}+${kvm_host_frag}`)
            }
        }

        ["linaro-base", "distribution"].forEach(frag => {
            addExtraIfExists(extra, kdir, `linaro/configs/${frag}.conf`);
        });

        if (fs.existsSync(`${kdir}/android/configs`)) {
            let android_extra = ""; // TODO - this previously was inside the for loop
            ['base', 'recommended'].forEach(frag => {
                let path = `android/configs/android-${frag}.cfg`;

                if (fs.existsSync(path)) {
                    android_extra += `+${path}`;
                }
            });

            if (android_extra) {
                configs.add(`${base_defconfig}${android_extra}`);

                /* Also build vexpress_defconfig for testing on QEMU */
                configs.add(`vexpress_defconfig${android_extra}`);
            }
        }
    }

    extra.forEach(e => {
        configs.add(`${base_defconfig}+${e}`);
    });
}

function getArchConfig(arch, config) {
    let compiler = 'gcc-7';
    //yes this hack is nasty, but until we've starting using >1 compilers it will do
    if (arch == 'mips') {
        compiler = 'gcc-6.3.0';
    }

    return {
        'ARCH': arch,
        'DEFCONFIG': config,
/*        'TREE': params.TREE,
        'TREE_NAME': params.TREE_NAME,
        'GIT_DESCRIBE': params.GIT_DESCRIBE,
        'GIT_DESCRIBE_VERBOSE': params.GIT_DESCRIBE_VERBOSE,
        'COMMIT_ID': params.COMMIT_ID,
        'BRANCH': params.BRANCH,
        'SRC_TARBALL': params.SRC_TARBALL,*/
        'COMPILER': compiler,
    };
}

/*def buildsComplete(job, arch) {
    def str_params = [
        'TREE_NAME': params.TREE_NAME,
        'ARCH': arch,
        'GIT_DESCRIBE': params.GIT_DESCRIBE,
        'BRANCH': params.BRANCH,
        'API': params.KCI_API_URL,
    ]
    def bool_params = [
        'EMAIL': params.EMAIL,
        'PUBLISH': params.PUBLISH,
    ]
    def job_params = []

    def j = new Job()
    j.addStrParams(job_params, str_params)
    j.addBoolParams(job_params, bool_params)
    build(job: job, parameters: job_params)
}*/

let kdir = process.env.WORKSPACE + '/linux'
let archs = params.ARCH_LIST.split(' ');
let arch_configs = [];

/*console.log(`
Tree:      ${params.TREE_NAME}
URL:       ${params.TREE}
Branch:    ${params.BRANCH}
Describe:  ${params.GIT_DESCRIBE}
Revision:  ${params.COMMIT_ID}
Archs:     ${archs.length}`);*/

archs.forEach(arch => {
    let configs = new Set;
    configs.add("allnoconfig");

    addDefconfigs(configs, kdir, arch);

    if (params.TREE_NAME != "stable" && params.TREE_NAME != "stable-rc") {
        addExtraConfigs(configs, kdir, arch);
    }

    configs.forEach(config => {
        arch_configs.push([arch, config]);
    });
});

let configs = {};

arch_configs.forEach(x => {
    let arch = x[0];
    let config = x[1];
    let key = `${config}_${arch}`;

    if (!params.CONFIG || params.CONFIG === key) {
        configs[key] = getArchConfig(arch, config);
    }
});

let keys = Object.keys(configs).sort();
let sortedConfigs = {};
keys.forEach(key => {
    sortedConfigs[key] = configs[key];
});

console.log(JSON.stringify(sortedConfigs));

// TODO: handle arch cleanup step
//stage("Complete") {
    /* ToDo: convert kernel-arch-complete as a stage in this job */
    //for (String arch: archs) {
        //buildsComplete("kernel-arch-complete", arch)
    //}
//}
