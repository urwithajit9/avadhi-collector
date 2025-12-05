    - name: Generate Release Body File
            run: |
            echo "## Avadhi Collector - v0.1.1" > release_notes.md
            echo "" >> release_notes.md
            echo "This release contains the Linux binary and systemd service file for persistent background operation." >> release_notes.md
            echo "" >> release_notes.md
            echo "### Linux Installation Instructions" >> release_notes.md
            echo "(See README for full details)" >> release_notes.md
            echo "1. Download and extract 'avadhi-linux.tar.gz'." >> release_notes.md
            echo "2. Follow the instructions in the 'install.sh' script to set up the systemd service." >> release_notes.md