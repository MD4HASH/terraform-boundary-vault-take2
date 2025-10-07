sudo systemctl unmask vault boundary-controller boundary-worker
sudo systemctl daemon-reload
sudo systemctl enable vault boundary-controller boundary-worker
sudo systemctl start vault boundary-controller boundary-worker