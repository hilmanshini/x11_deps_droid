project('libxkbfile', 'c',
        version: '1.2.0',
        meson_version: '>= 0.57.0',
        license: 'MIT'
)

cc = meson.get_compiler('c')

func_prefix = '''
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
'''

cc_conf = configuration_data({
    'HAVE_REALLOCF': cc.has_function('reallocf', prefix: func_prefix) ? '1' : false,
    'HAVE_STRNDUP': cc.has_function('strndup', prefix: func_prefix) and
                    cc.has_header_symbol('string.h', 'strndup') ? '1' : false,
    'HAVE_UNLOCKED_STDIO': cc.has_function('getc_unlocked', prefix: func_prefix) ? '1' : false
})
# strcasecmp is spelled '_stricmp' on Windows
if not cc.has_function('strcasecmp', prefix: func_prefix)
    if cc.has_function('_stricmp', prefix: func_prefix)
        cc_conf.set('strcasecmp', '_stricmp', description: 'Replacement for strcasecmp, if necessary')
    else
        error('strcasecmp (or _stricmp) is mandatory')
    endif
endif
configure_file(output: 'config.h',
               configuration: cc_conf)
add_project_arguments('-DHAVE_CONFIG_H', language : ['c'])

pc_conf = configuration_data({
    'prefix': get_option('prefix'),
    'exec_prefix': '${prefix}',
    'libdir': '${exec_prefix}' / get_option('libdir'),
    'includedir': '${prefix}' / get_option('includedir'),
    'PACKAGE_VERSION': meson.project_version()
})
configure_file(output: 'xkbfile.pc',
               input: 'xkbfile.pc.in',
               install: true,
               install_dir: get_option('libdir') / 'pkgconfig',
               configuration: pc_conf)

subdir('src')
