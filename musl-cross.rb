class MuslCross < Formula
  desc "Linux cross compilers based on musl libc"
  homepage "https://github.com/richfelker/musl-cross-make"
  url "https://github.com/richfelker/musl-cross-make/archive/v0.9.7.tar.gz"
  sha256 "876173e2411b5f50516723c63075655a9aac55ee3804f91adfb61f0a85af8f38"
  revision 1
  head "https://github.com/richfelker/musl-cross-make.git"

  bottle do
    root_url "https://dl.bintray.com/filosottile/generic"
    cellar :any_skip_relocation
    sha256 "60cd9b07a9024bdbda03cba4e44c84fa328fb1370aec330be8da2513d7e9d017" => :high_sierra
  end

  option "with-aarch64", "Build cross-compilers targeting arm-linux-muslaarch64"
  option "with-arm-hf", "Build cross-compilers targeting arm-linux-musleabihf"
  option "with-arm", "Build cross-compilers targeting arm-linux-musleabi"
  option "with-i486", "Build cross-compilers targeting i486-linux-musl"
  option "with-mips", "Build cross-compilers targeting mips-linux-musl"
  option "without-x86_64", "Do not build cross-compilers targeting x86_64-linux-musl"

  depends_on "gnu-sed" => :build
  depends_on "make" => :build

  resource "linux-4.4.10.tar.xz" do
    url "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.4.10.tar.xz"
    sha256 "4ac22e4a619417213cfdab24714413bb9118fbaebe6012c6c89c279cdadef2ce"
  end

  resource "mpfr-3.1.4.tar.bz2" do
    url "https://ftp.gnu.org/gnu/mpfr/mpfr-3.1.4.tar.bz2"
    sha256 "d3103a80cdad2407ed581f3618c4bed04e0c92d1cf771a65ead662cc397f7775"
  end

  resource "mpc-1.0.3.tar.gz" do
    url "https://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz"
    sha256 "617decc6ea09889fb08ede330917a00b16809b8db88c29c31bfbb49cbf88ecc3"
  end

  resource "gmp-6.1.1.tar.bz2" do
    url "https://ftp.gnu.org/gnu/gmp/gmp-6.1.1.tar.bz2"
    sha256 "a8109865f2893f1373b0a8ed5ff7429de8db696fc451b1036bd7bdf95bbeffd6"
  end

  resource "musl-1.1.18.tar.gz" do
    url "https://www.musl-libc.org/releases/musl-1.1.18.tar.gz"
    sha256 "d017ee5d01aec0c522a1330fdff06b1e428cb409e1db819cc4935d5da4a5a118"
  end

  resource "binutils-2.27.tar.bz2" do
    url "https://ftp.gnu.org/gnu/binutils/binutils-2.27.tar.bz2"
    sha256 "369737ce51587f92466041a97ab7d2358c6d9e1b6490b3940eb09fb0a9a6ac88"
  end

  resource "config.sub" do
    url "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=3d5db9ebe860"
    sha256 "75d5d255a2a273b6e651f82eecfabf6cbcd8eaeae70e86b417384c8f4a58d8d3"
  end

  resource "gcc-6.3.0.tar.bz2" do
    url "https://ftp.gnu.org/gnu/gcc/gcc-6.3.0/gcc-6.3.0.tar.bz2"
    sha256 "f06ae7f3f790fbf0f018f6d40e844451e6bc3b7bc96e128e63b09825c1f8b29f"
  end

  resource "isl-0.15.tar.bz2" do
    url "http://isl.gforge.inria.fr/isl-0.15.tar.bz2"
    sha256 "8ceebbf4d9a81afa2b4449113cee4b7cb14a687d7a549a963deb5e2a41458b6b"
  end

  def install
    ENV.deparallelize

    if build.with? "x86_64"
      targets = ["x86_64-linux-musl"]
    else
      targets = []
    end
    if build.with? "aarch64"
      targets.push "aarch64-linux-musl"
    end
    if build.with? "arm-hf"
      targets.push "arm-linux-musleabihf"
    end
    if build.with? "arm"
      targets.push "arm-linux-musleabi"
    end
    if build.with? "i486"
      targets.push "i486-linux-musl"
    end
    if build.with? "mips"
      targets.push "mips-linux-musl"
    end

    (buildpath/"resources").mkpath
    resources.each do |resource|
      cp resource.fetch, buildpath/"resources"/resource.name
    end

    (buildpath/"config.mak").write <<~EOS
      SOURCES = #{buildpath/"resources"}
      OUTPUT = #{libexec}

      # Recommended options for faster/simpler build:
      COMMON_CONFIG += --disable-nls
      GCC_CONFIG += --enable-languages=c,c++
      GCC_CONFIG += --disable-libquadmath --disable-decimal-float
      GCC_CONFIG += --disable-multilib
      # Recommended options for smaller build for deploying binaries:
      COMMON_CONFIG += CFLAGS="-g0 -Os" CXXFLAGS="-g0 -Os" LDFLAGS="-s"
      # Keep the local build path out of binaries and libraries:
      COMMON_CONFIG += --with-debug-prefix-map=$(PWD)=

      # Explicitly enable libisl support to avoid opportunistic linking
      ISL_VER = 0.15

      # https://llvm.org/bugs/show_bug.cgi?id=19650
      ifeq ($(shell $(CXX) -v 2>&1 | grep -c "clang"), 1)
      TOOLCHAIN_CONFIG += CXX="$(CXX) -fbracket-depth=512"
      endif
    EOS

    ENV.prepend_path "PATH", "#{Formula["gnu-sed"].opt_libexec}/gnubin"
    targets.each do |target|
      system Formula["make"].opt_bin/"gmake", "install", "TARGET=#{target}"
    end

    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    (testpath/"hello.c").write <<~EOS
      #include <stdio.h>

      main()
      {
          printf("Hello, world!");
      }
    EOS

    if build.with? "x86_64"
      system "#{bin}/x86_64-linux-musl-cc", (testpath/"hello.c")
    end
    if build.with? "i486"
      system "#{bin}/i486-linux-musl-cc", (testpath/"hello.c")
    end
    if build.with? "aarch64"
      system "#{bin}/aarch64-linux-musl-cc", (testpath/"hello.c")
    end
    if build.with? "arm-hf"
      system "#{bin}/arm-linux-musleabihf-cc", (testpath/"hello.c")
    end
    if build.with? "arm"
      system "#{bin}/arm-linux-musleabi-cc", (testpath/"hello.c")
    end
    if build.with? "mips"
      system "${bin}/mips-linux-musl-cc", (testpath/"hello.c")
    end
  end
end
