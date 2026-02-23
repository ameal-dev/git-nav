class GitNav < Formula
  desc "Smart Git branch navigator with fuzzy search, ticket lookup, and branch history"
  homepage "https://github.com/ameal-dev/git-nav"
  url "https://github.com/ameal-dev/git-nav/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "<replace-after-tagging>"
  license "MIT"

  depends_on "bash"

  def install
    bin.install "bin/git-nav"
  end

  test do
    assert_match "git-nav 1.0.0", shell_output("#{bin}/git-nav --version")
  end
end
