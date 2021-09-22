# Chart Releaser (Private) Action

GitHub Action inspired by the official [Chart Releaser Action](https://github.com/helm/chart-releaser-action) by Helm, to make a Helm Chart repository (public) out of a private one, on GitHub.

## Motivation
This aims to fix the official action's limitations; specifically, the fact that you can't upload packages nor update/push the index.yaml to a repository which is not the one where the action is running on.

Private repositories releases need authentication to be accessed, which makes it harder to use with chart releaser. Another fact is that private repositories cannot use GitHub Pages unless on a paid tier.

This creates an issue for those with a private repository, that's why the idea/strategy that this action takes is:
1. Use the action on a private repository, which contains the charts.
2. Upload chart packages and deploy the index.yaml to a separate, public repository, which does not contain the charts' source code (otherwise it defeats the point of this action).

## Pre-requisites
1. A private GitHub repository (public untested) that contains helm charts source code under a directory (e.g. `/charts`)
2. A public GitHub repository where the Helm Chart packages and `index.yaml` will be uploaded/deployed to

## Usage

On the private repo:
```yaml
name: Release Charts

on:
  push:
    branches:
      - main

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
        with:
          fetch-depth: 0

      - name: Install Helm
        uses: azure/setup-helm@v1
        with:
          version: v3.4.0

      - name: Configure Git
        shell: bash
        run: |
          git config --global user.name "$GITHUB_ACTOR"
          git config --global user.email "$GITHUB_ACTOR@users.noreply.github.com"

      - name: Run chart-releaser
        uses: Maikuh/chart-releaser-private-action@main
        with:
          reposOwner: the-owner
          publicRepo: helm-charts-public
          token: ${{ secrets.GH_TOKEN }}
        #   chartsDir: charts # default is 'charts'
```
