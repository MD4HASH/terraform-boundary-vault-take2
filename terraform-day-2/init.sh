sudo mv /tmp/boundary-controller.service /etc/systemd/system/boundary-controller.service
sudo mv /tmp/boundary-worker.service /etc/systemd/system/boundary-worker.service


sudo /usr/bin/boundary database init -config=/etc/boundary.d/boundary-controller.hcl > ~/boundary_init


sudo systemctl unmask vault boundary-controller boundary-worker
sudo systemctl daemon-reload
sudo systemctl enable vault boundary-controller boundary-worker
sudo systemctl start vault boundary-controller boundary-worker