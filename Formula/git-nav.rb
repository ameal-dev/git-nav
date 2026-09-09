class GitNav < Formula
  desc "Smart Git branch navigator with fuzzy search, ticket lookup, and branch history"
  homepage "https://github.com/ameal-dev/git-nav"
  url "https://github.com/ameal-dev/git-nav/archive/refs/tags/v1.2.1.tar.gz"
  sha256 "9ef0a8f9d4c95691219dfd50737c848e79cf661307fa14091dce8a8e681359f0"
  license "MIT"

  depends_on "bash"
  depends_on "git-delta"

  def install
    bin.install "bin/git-nav"
    lib.install "lib/git-nav-tutorial.sh"
  end

  test do
    assert_match "git-nav 1.2.1", shell_output("#{bin}/git-nav --version")
  end
end
