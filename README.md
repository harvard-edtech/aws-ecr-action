# DCE ECR Action

This action is designed to create docker images for the various
[harvard-edtech](https://github.com/harvard-edtech) nodejs apps.


## Parameters
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `access_key_id` | `string` | | Your AWS access key id |
| `secret_access_key` | `string` | | Your AWS secret access key |
| `account_id` | `string` | | Your AWS Account ID |
| `repo` | `string` | | Name of your ECR repository |
| `region` | `string` | | Your AWS region |
| `create_repo` | `boolean` | `true` | Set this to true to create the repository if it does not already exist |
| `tags` | `string` | `latest` | Comma-separated string of ECR image tags (ex latest,1.0.0,) |
| `add_branch_tag` | `boolean` | `true` | Add an additional image tag based on the branch/revision name |
| `dockerfile` | `string` | `Dockerfile` | Name of Dockerfile to use |
| `extra_build_args` | `string` | `""` | Extra flags to pass to docker build (see docs.docker.com/engine/reference/commandline/build) |
| `path` | `string` | `.` | Path to Dockerfile, defaults to the working directory |

## A note about the Dockerfile

If the project using this action does not have a `Dockerfile` in the project root directory
a generic [default.Dockerfile](default.Dockerfile), which will work for the majority of our nodejs apps, will
be used instead.

## Example Usage

This is how we roll at DCE

```yaml
env:
  REPOSITORY_NAME: hdce/my-cool-node-app

jobs:
  build_and_push:
    runs-on: ubuntu-latest
    steps:
      - name: Check out the repo
        uses: actions/checkout@v2

      - name: Build + Push
        uses: harvard-edtech/dce-ecr-action@v1
        with:
          access_key_id:  ${{ secrets.PUSH_TO_ECR_AWS_ACCESS_KEY_ID }}
          secret_access_key: ${{ secrets.PUSH_TO_ECR_AWS_SECRET_ACCESS_KEY }}
          account_id: ${{ secrets.AWS_ACCOUNT_ID }}
          repo: ${{ env.REPOSITORY_NAME }}
          region: ${{ secrets.AWS_DEFAULT_REGION }}
          tags: ${{ github.sha }}
          add_branch_tag: true
```

## License
The MIT License (MIT)
