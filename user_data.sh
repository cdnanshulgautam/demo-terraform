#!/bin/bash
              sudo apt update -y && sudo apt upgrade -y
              sudo apt install -y awscli
              sudo apt install openjdk-11-jdk -y
              curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
              sudo apt install -y nodejs
              java -version
              node -v
              npm -v
              if ! file -s /dev/xvdh | grep -q 'ext4'; then
                  sudo mkfs -t ext4 /dev/xvdh
              fi
              sudo mkdir -p /mnt/external_disk_1
              sudo mount /dev/xvdh /mnt/external_disk_1
              echo '/dev/xvdh /mnt/external_disk_1 ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
              sudo chown -R ubuntu:ubuntu /mnt/external_disk_1
              sudo chmod -R 755 /mnt/external_disk_1

              # Log instance creation to CloudWatch
              INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
              aws logs put-log-events \
                --log-group-name "/aws/ec2/audit_trail" \
                --log-stream-name "$INSTANCE_ID" \
                --log-events file://<(echo '[{"timestamp": $(date +%s%3N), "message": "Instance Created: '"$INSTANCE_ID"'"}]')

              # Store artifact history in S3
              echo '{"artifact_id": "'"$INSTANCE_ID"'", "timestamp": "$(date -u)", "action": "CREATE", "description": "Instance Created"}' > /tmp/artifact.json
              aws s3 cp /tmp/artifact.json s3://$(echo "$artifact_bucket_name")/artifacts/$INSTANCE_ID.json