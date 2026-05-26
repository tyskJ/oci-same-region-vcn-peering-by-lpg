.. image:: ./doc/001samune.png

=====================================================================
OCI Local Peering Gateway で同一リージョン VCN 間を接続する
=====================================================================
* `詳細 <>`_

=====================================================================
構成図
=====================================================================
.. image:: ./doc/drawio/architecture.drawio.png

=====================================================================
デプロイ - Terraform -
=====================================================================

作業環境 - ローカル -
=====================================================================
* macOS Tahoe ( v26.5 )
* Visual Studio Code 1.121.0
* oci cli 3.71.0
* Python 3.14.2

フォルダ構成
=====================================================================
* `こちら <./folder.md>`_ を参照

前提条件
=====================================================================
* ``manage all-resources IN TENANCY`` を付与した IAM グループに所属する IAM ユーザーが作成されていること
* 以下コマンドを実行し、*ADMIN* プロファイルを作成していること (デフォルトリージョンは *ap-tokyo-1* )

.. code-block:: bash

  oci session authenticate

事前作業(1)
=====================================================================
1. 各種モジュールインストール
---------------------------------------------------------------------
* `GitHub <https://github.com/tyskJ/common-environment-setup>`_ を参照

事前作業 - ローカル -
=====================================================================
1. 定義ファイルの圧縮
---------------------------------------------------------------------
.. code-block:: bash

  ZIP_FILE="stack.zip"

.. code-block:: bash

  zip -r "${ZIP_FILE}" envs modules

実作業 - OCI Resource Manager -
=====================================================================
1. スタック作成
---------------------------------------------------------------------
.. code-block:: bash

  REGION=$(awk -F= '/\[ADMIN\]/{f=1} f && /^region=/{print $2; exit}' ~/.oci/config)
  SYSTEM_NAME="oci-same-region-vcn-peering-by-lpg"
  TF_VER="1.5.x"
  SOURCE_IP="送信元IPアドレス(CIDR形式)"
  STACK_NAME="${SYSTEM_NAME}-stack"

.. code-block:: bash

  cat <<EOF > terraform.tfvars.json
  {
    "tenancy_ocid": "${TENANCY_ID}",
    "region": "${REGION}",
    "system_name": "${SYSTEM_NAME}",
    "vcn_a_cidr": "10.0.0.0/16",
    "vcn_b_cidr": "172.16.0.0/16",
    "source_ip": "${SOURCE_IP}"
  }
  EOF

.. code-block:: bash

  oci resource-manager stack create \
  --compartment-id "${TENANCY_ID}" \
  --display-name "${STACK_NAME}" \
  --description "Dev Stack" \
  --config-source "${ZIP_FILE}" \
  --working-directory "envs" \
  --terraform-version "${TF_VER}" \
  --variables file://terraform.tfvars.json \
  --wait-for-state "ACTIVE" \
  --profile ADMIN --auth security_token

2. Plan Job 作成
---------------------------------------------------------------------
.. code-block:: bash

  STACK_ID=$(oci resource-manager stack list \
    --all \
    --compartment-id "${TENANCY_ID}" \
    --display-name "${STACK_NAME}" \
    --profile ADMIN --auth security_token \
    --query 'data[0].id' \
    --raw-output)

.. code-block:: bash

  PLAN_JOB_ID=$(oci resource-manager job create-plan-job \
    --stack-id "${STACK_ID}" \
    --display-name "${STACK_NAME}-plan" \
    --wait-for-state "SUCCEEDED" \
    --profile ADMIN --auth security_token \
    --query 'data.id' \
    --raw-output)

.. code-block:: bash

  oci resource-manager job get-job-tf-plan \
    --job-id "${PLAN_JOB_ID}" \
    --tf-plan-format JSON \
    --file tfplan.json \
    --profile ADMIN \
    --auth security_token >/dev/null

  jq -r '
  .resource_changes[]
  ' tfplan.json

3. Deploy
---------------------------------------------------------------------
.. code-block:: bash

  oci resource-manager job create-apply-job \
    --stack-id "${STACK_ID}" \
    --execution-plan-strategy FROM_PLAN_JOB_ID \
    --execution-plan-job-id "${PLAN_JOB_ID}" \
    --display-name "${STACK_NAME}-apply" \
    --wait-for-state SUCCEEDED \
    --profile ADMIN \
    --auth security_token

後片付け - ローカル -
=====================================================================
1. 環境削除
---------------------------------------------------------------------
.. code-block:: bash

  oci resource-manager job create-destroy-job \
    --stack-id "${STACK_ID}" \
    --execution-plan-strategy AUTO_APPROVED \
    --display-name "${STACK_NAME}-destroy" \
    --wait-for-state SUCCEEDED \
    --profile ADMIN \
    --auth security_token \
    --query 'data.id' \
    --raw-output

.. code-block:: bash

  oci resource-manager stack delete \
    --stack-id "${STACK_ID}" \
    --force \
    --wait-for-state DELETED \
    --profile ADMIN \
    --auth security_token

番外編
=====================================================================
スタック更新
---------------------------------------------------------------------
.. code-block:: bash

  oci resource-manager stack update \
    --stack-id "${STACK_ID}" \
    --config-source ${ZIP_FILE} \
    --profile ADMIN \
    --auth security_token

.. code-block:: bash

  PLAN_JOB_ID=$(oci resource-manager job create-plan-job \
    --stack-id "${STACK_ID}" \
    --display-name "${STACK_NAME}-plan" \
    --wait-for-state "SUCCEEDED" \
    --profile ADMIN --auth security_token \
    --query 'data.id' \
    --raw-output)

.. code-block:: bash

  oci resource-manager job get-job-tf-plan \
    --job-id "${PLAN_JOB_ID}" \
    --tf-plan-format JSON \
    --file tfplan.json \
    --profile ADMIN \
    --auth security_token >/dev/null

  jq -r '
  .resource_changes[]
  ' tfplan.json

.. code-block:: bash

  oci resource-manager job create-apply-job \
    --stack-id "${STACK_ID}" \
    --execution-plan-strategy FROM_PLAN_JOB_ID \
    --execution-plan-job-id "${PLAN_JOB_ID}" \
    --display-name "${STACK_NAME}-apply" \
    --wait-for-state SUCCEEDED \
    --profile ADMIN \
    --auth security_token

オブジェクトバルクアップロード
---------------------------------------------------------------------
.. code-block:: bash

  oci os object bulk-upload \
    --bucket-name "${BUCKET_NAME}" \
    --src-dir . \
    --overwrite \
    --exclude ".gitconfig" \
    --exclude "*.zip" \
    --exclude "*.md" \
    --exclude "*.rst" \
    --exclude ".gitignore" \
    --exclude "doc/*" \
    --exclude ".git/*" \
    --exclude ".DS_Store" \
    --profile ADMIN --auth security_token

オブジェクトバルクデリート
---------------------------------------------------------------------
.. code-block:: bash

  oci os object bulk-delete \
    --bucket-name "${BUCKET_NAME}" \
    --force \
    --profile ADMIN --auth security_token

参考資料
=====================================================================
リファレンス
---------------------------------------------------------------------
* `terraform_data resource reference <https://developer.hashicorp.com/terraform/language/resources/terraform-data>`_
* `Backend block configuration overview <https://developer.hashicorp.com/terraform/language/backend#partial-configuration>`_
* `All Image Families - Oracle Cloud Infrastructure Documentation/Images <https://docs.oracle.com/en-us/iaas/images/>`_
* `タグおよびタグ・ネームスペースの概念 - Oracle Cloud Infrastructureドキュメント <https://docs.oracle.com/ja-jp/iaas/Content/Tagging/Tasks/managingtagsandtagnamespaces.htm#Who>`_
* `About the DNS Domains and Hostnames - Oracle Cloud Infrastructure Documentation <https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/dns.htm#About>`_

ブログ
---------------------------------------------------------------------
* `Terraformでmoduleを使わずに複数環境を構築する - Zenn <https://zenn.dev/smartround_dev/articles/5e20fa7223f0fd>`_
* `Terraformでmoduleを使わずに複数環境を構築して感じた利点 - SpeakerDeck <https://speakerdeck.com/shonansurvivors/building-multiple-environments-without-using-modules-in-terraform>`_
* `個人的備忘録：Terraformディレクトリ整理の個人メモ（ファイル分割編） - Qiita <https://qiita.com/free-honda/items/5484328d5b52326ed87e>`_
* `Terraformの auto.tfvars を使うと、環境管理がずっと楽になる話 - note <https://note.com/minato_kame/n/neb271c81e0e2>`_
* `Terraform v1.9 では null_resource を安全に terraform_data に置き換えることができる -Zenn <https://zenn.dev/terraform_jp/articles/tf-null-resource-to-terraform-data>`_
* `Terraform cloudinit Provider を使って MIME multi-part 形式の cloud-init 設定を管理する - HatenaBlog <https://chaya2z.hatenablog.jp/entry/2025/10/15/040000>`_
* `TerraformのDynamic Blocksを使ってみた - DevelopersIO <https://dev.classmethod.jp/articles/terraform-dynamic-blocks/>`_