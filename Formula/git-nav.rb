class GitNav < Formula
  desc "Smart Git branch navigator with fuzzy search, ticket lookup, and branch history"
  homepage "https://github.com/ameal-dev/git-nav"
  url "https://github.com/ameal-dev/git-nav/archive/refs/tags/v1.2.0.tar.gz"
  sha256 "1a58383063a82e4b910c7afe39c1621cdca9bbdb4af656ef4d5d5a4de51744aa"
  license "MIT"

  depends_on "bash"
  depends_on "git-delta"

  def install
    bin.install "bin/git-nav"
    lib.install "lib/git-nav-tutorial.sh"
  end

  test do
    assert_match "git-nav 1.2.0", shell_output("#{bin}/git-nav --version")
  end
end
