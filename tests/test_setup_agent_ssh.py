import os
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts" / "setup-agent-ssh"


class SetupAgentSshTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.repository = self.root / "repository"
        self.ssh_dir = self.root / "ssh"
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        subprocess.run(["git", "init", "-q", str(self.repository)], check=True)
        subprocess.run(
            [
                "git",
                "-C",
                str(self.repository),
                "remote",
                "add",
                "origin",
                "https://github.com/example/project.git",
            ],
            check=True,
        )
        self.host_key = self.root / "host-key"
        subprocess.run(
            ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(self.host_key)],
            check=True,
        )
        self._write_fake_commands()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _write_fake_commands(self) -> None:
        public_key = self.host_key.with_suffix(".pub").read_text().split()
        key_type, key_data = public_key[:2]
        keyscan = self.bin_dir / "ssh-keyscan"
        keyscan.write_text(
            textwrap.dedent(
                f"""\
                #!/usr/bin/env bash
                printf '%s\\n' '[ssh.github.com]:443 {key_type} {key_data}'
                """
            )
        )
        ssh = self.bin_dir / "ssh"
        ssh.write_text(
            textwrap.dedent(
                """\
                #!/usr/bin/env bash
                echo "Hi example/project! You've successfully authenticated, but GitHub does not provide shell access."
                exit 1
                """
            )
        )
        keyscan.chmod(0o755)
        ssh.chmod(0o755)

    def _run(self, answers: str, repository: str = "example/project") -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment.update(
            {
                "AGENT_SSH_DIR": str(self.ssh_dir),
                "AGENT_SSH_WORKSPACE": str(self.repository),
                "PATH": f"{self.bin_dir}:{environment['PATH']}",
                "TEMPLATE_DEVCONTAINER": "1",
            }
        )
        return subprocess.run(
            [str(SCRIPT), repository],
            cwd=self.repository,
            env=environment,
            input=answers,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_configures_repository_scoped_key_and_remote(self) -> None:
        result = self._run("y\ny\ny\n")
        self.assertEqual(result.returncode, 0, result.stderr)

        private_key = self.ssh_dir / "id_ed25519_agent_example_project"
        public_key = private_key.with_suffix(".pub")
        known_hosts = self.ssh_dir / "known_hosts_agent_example_project"
        self.assertTrue(private_key.is_file())
        self.assertTrue(public_key.is_file())
        self.assertEqual(stat.S_IMODE(private_key.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(public_key.stat().st_mode), 0o644)
        self.assertEqual(stat.S_IMODE(known_hosts.stat().st_mode), 0o600)
        self.assertEqual(len(known_hosts.read_text().splitlines()), 1)

        fetch = subprocess.run(
            ["git", "-C", str(self.repository), "remote", "get-url", "origin"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        push = subprocess.run(
            ["git", "-C", str(self.repository), "remote", "get-url", "--push", "origin"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        command = subprocess.run(
            ["git", "-C", str(self.repository), "config", "--local", "core.sshCommand"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        self.assertEqual(fetch, "https://github.com/example/project.git")
        self.assertEqual(push, "ssh://git@ssh.github.com:443/example/project.git")
        self.assertIn(str(private_key), command)
        self.assertIn(str(known_hosts), command)

        second = self._run("y\ny\n")
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertIn("was not overwritten", second.stdout)
        self.assertEqual(len(known_hosts.read_text().splitlines()), 1)

    def test_refuses_an_unrelated_origin_before_creating_a_key(self) -> None:
        result = self._run("", repository="other/project")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing SSH changes", result.stderr)
        self.assertFalse(self.ssh_dir.exists())


if __name__ == "__main__":
    unittest.main()
