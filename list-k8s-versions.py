#!/usr/bin/env python3
"""List available Kubernetes versions from k8s-versions.yaml"""

import yaml
import sys

def list_versions():
    try:
        with open('k8s-versions.yaml', 'r') as f:
            data = yaml.safe_load(f)

        print("\nAvailable Kubernetes versions:")
        print("─" * 60)

        for version, info in sorted(data['versions'].items(), reverse=True):
            release_date = info.get('release_date', 'N/A')
            notes = info.get('notes', '').strip().split('\n')[0]
            print(f"  • {version:10} (Released: {release_date})")
            if notes:
                print(f"    {notes}")

        print("\nTo build a specific version:")
        print("  make build K8S_VERSION=1.29.6")
        print("  ./create-k8s-bundle.sh 1.29.6")
        print()

    except FileNotFoundError:
        print("Error: k8s-versions.yaml not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

def show_matrix():
    try:
        with open('k8s-versions.yaml', 'r') as f:
            data = yaml.safe_load(f)

        print("\nKubernetes Version Matrix:")
        print("─" * 60)

        for version, info in sorted(data['versions'].items(), reverse=True):
            print(f"\n{version}:")
            print(f"  Containerd: {info['container_runtime']['containerd']['version']}")
            print(f"  Runc:       {info['container_runtime']['runc']['version']}")
            print(f"  CNI:        {info['cni']['plugins_version']}")
            print(f"  Calico:     {info['cni']['calico_version']}")

        print()

    except FileNotFoundError:
        print("Error: k8s-versions.yaml not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--matrix':
        show_matrix()
    else:
        list_versions()
