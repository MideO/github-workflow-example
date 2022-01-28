## github-workflow-example

# Pre-requisites
- python3

### Testing
**Run the unit tests**
```bash
make test 
```

### Packaging
**Package the artifacts**
```bash
make package 
```

### Releasing
**Push the latest release tag to git**
```bash
make push-latest-release-tag 
```

#### pushing to s3 in jenkins pipeline
```bash
make push-s3 
```
