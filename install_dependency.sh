#!/bin/bash
set -e
echo "Build Clash core"

cd ClashFX/goClash
python3 build_clash_universal.py
cd ../..

echo "Pod install"
bundle install --jobs 4
bundle exec pod install
echo "delete old files"
rm -f ./ClashFX/Resources/Country.mmdb
rm -rf ./ClashFX/Resources/dashboard
rm -f GeoLite2-Country.*
echo "install mmdb"
curl -LO https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/Country.mmdb
gzip Country.mmdb
mv Country.mmdb.gz ./ClashFX/Resources/Country.mmdb.gz
echo "install dashboard"
cd ClashFX/Resources
if ! git clone --depth 1 -b gh-pages https://github.com/MetaCubeX/metacubexd.git dashboard 2>/dev/null; then
    echo "Warning: Failed to clone dashboard, creating placeholder"
    mkdir -p dashboard
    echo "<html><body><h1>Dashboard not available</h1></body></html>" > dashboard/index.html
fi

if [ -d "dashboard/.git" ]; then
    cd dashboard
    rm -rf CNAME .git .nojekyll
    cd ..
fi
cd ../..
