class DiagnosesController < ApplicationController
  skip_before_action :require_login, only: %i[]

  def index
    @diagnoses = Diagnosis.includes(:user).order(created_at: :desc).page(params[:page])
  end

  def new
    @diagnosis = Diagnosis.new
    # Tagsテーブルから取得するように修正する。
    @tag_list = [['オフィス（固定席）', 11], ['オフィス（フリーアドレス）', 12], ['書斎', 13], ['自分の部屋', 14], ['リビング', 15], ['カフェ', 16], ['その他', 17]]
  end

  def show
    @diagnosis = Diagnosis.find_by(id: params[:id])
  end

  def tagged
    @tagged_diagnoses = Diagnosis.includes(:user).joins(:tags).where(tags: { tag_name: params[:tag_name] }).order(created_at: :desc).page(params[:page])
  end

  def favorites
    @favorite_diagnoses = current_user.favorite_diagnoses.includes(:user).order(created_at: :desc).page(params[:page])
  end

  def create
    @diagnosis = current_user.diagnoses.build(diagnosis_params)
  
    #.tempfileメソッドはアップロードされたファイルが一時的に保存されているTempfileオブジェクトにアクセスするためのメソッド。
    # .pathメソッドでそのTempfileオブジェクトのファイルシステム上のパスを取得。後続の処理で画像ファイルを読み込んだり、外部のAPIに送信したりするために使用されるパス)
    if params[:diagnosis][:desk_image].present?
      uploaded_image_path = params[:diagnosis][:desk_image].tempfile.path
    end
  
    # 色情報をcolor_infoカラムにセット + color_nameカラム（処理後）にセット。
    if uploaded_image_path.present?
      analysis_result = GoogleCloudVisionApi.analyze_image(uploaded_image_path)
      @diagnosis.color_info = analysis_result
      @diagnosis.color_name = RakutenApi.color_name(analysis_result)
    end

    # 翻訳前の回答をresult_enカラムにセット。
    if @diagnosis.color_info.present?
      response = OpenAiApi.chat(@diagnosis.color_info, @diagnosis.desk_work, 
        @diagnosis.tags.each do |tag|
          tag.tag_name
        end) 
      @diagnosis.result_en = response.dig("choices", 0, "message", "content") 
    end

    # 翻訳後の回答をresult_jpカラムにセット。
    if @diagnosis.result_en.present?
      translated_response = DeeplApi.translate(@diagnosis.result_en, 'JA')
      @diagnosis.result_jp = translated_response
    end

    if @diagnosis.save
      redirect_to diagnosis_path(@diagnosis), success: t('flash_message.diagnosed')
    else
      flash.now[:danger] = t('flash_message.not_diagnosed')
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    diagnosis = current_user.diagnoses.find_by(id: params[:id])
    diagnosis.destroy!
    redirect_to diagnoses_path, success: t('flash_message.delete', item: Diagnosis.model_name.human)
  end

  private

  def diagnosis_params
    params.require(:diagnosis).permit(:desk_image, :desk_work, :desk_image_cache, :tag_ids)
  end
end
