class GitNav < Formula
  desc "Smart Git branch navigator with fuzzy search, ticket lookup, and branch history"
  homepage "https://github.com/ameal-dev/git-nav"
  url "https://github.com/ameal-dev/git-nav/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "09061d481895b903cca8a7725de398a9d69068e1fa6389c4fcb49a39eadc6b43"
  license "MIT"

  depends_on "bash"
  depends_on "git-delta"

  def install
    bin.install "bin/git-nav"
    lib.install "lib/git-nav-tutorial.sh"
  end

  test do
    assert_match "git-nav 1.0.0", shell_output("#{bin}/git-nav --version")
  end
end
