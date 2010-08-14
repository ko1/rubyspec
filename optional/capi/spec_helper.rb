require File.expand_path('../../../spec_helper', __FILE__)

require 'rbconfig'

def compile_extension(path, name)
  ext       = File.join(path, "#{name}_spec")
  source    = "#{ext}.c"
  obj       = "#{ext}.o"
  lib       = "#{ext}.#{RbConfig::CONFIG['DLEXT']}"
  signature = "#{ext}.sig"

  # Generate a version.h file for specs to use
  File.open File.expand_path("../ext/rubyspec_version.h", __FILE__), "w" do |f|
    # Yes, I know CONFIG variables exist for these, but
    # who knows when those could be removed without warning.
    major, minor, teeny = RUBY_VERSION.split(".")
    f.puts "#define RUBY_VERSION_MAJOR  #{major}"
    f.puts "#define RUBY_VERSION_MINOR  #{minor}"
    f.puts "#define RUBY_VERSION_TEENY  #{teeny}"
  end

  # TODO use rakelib/ext_helper.rb?
  arch_hdrdir = nil
  ruby_hdrdir = nil

  if RUBY_NAME == 'rbx'
    hdrdir = Rubinius::HDR_PATH
  elsif RUBY_NAME =~ /^ruby/
    if hdrdir = RbConfig::CONFIG["rubyhdrdir"]
      arch_hdrdir = File.join hdrdir, RbConfig::CONFIG["arch"]
      ruby_hdrdir = File.join hdrdir, "ruby"
    else
      hdrdir = RbConfig::CONFIG["archdir"]
    end
  else
    raise "Don't know how to build C extensions with #{RUBY_NAME}"
  end

  ruby_header     = File.join(hdrdir, "ruby.h")
  rubyspec_header = File.join(path, "rubyspec.h")

  return lib if File.exists?(signature) and
                IO.read(signature).chomp == RUBY_NAME and
                File.exists?(lib) and File.mtime(lib) > File.mtime(source) and
                File.mtime(lib) > File.mtime(ruby_header) and
                File.mtime(lib) > File.mtime(rubyspec_header)

  # avoid problems where compilation failed but previous shlib exists
  File.delete lib if File.exists? lib

  cc        = RbConfig::CONFIG["CC"]
  cflags    = (ENV["CFLAGS"] || RbConfig::CONFIG["CFLAGS"]).dup
  cflags   += " -fPIC" unless cflags.include?("-fPIC")
  incflags  = "-I#{path} -I#{hdrdir}"
  incflags << " -I#{arch_hdrdir}" if arch_hdrdir
  incflags << " -I#{ruby_hdrdir}" if ruby_hdrdir

  `#{cc} #{incflags} #{cflags} -c #{source} -o #{obj}`

  ldshared  = RbConfig::CONFIG["LDSHARED"]
  libpath   = "-L#{path}"
  libs      = RbConfig::CONFIG["LIBS"]
  dldflags  = RbConfig::CONFIG["DLDFLAGS"]

  `#{ldshared} #{obj} #{libpath} #{dldflags} #{libs} -o #{lib}`

  # we don't need to leave the object file around
  File.delete obj if File.exists? obj

  File.open(signature, "w") { |f| f.puts RUBY_NAME }

  lib
end

def load_extension(name)
  path = File.join(File.dirname(__FILE__), 'ext')

  ext = compile_extension path, name
  require ext
end