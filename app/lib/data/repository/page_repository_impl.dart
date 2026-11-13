import '../../core/config/app_config.dart';
import '../../domain/model/content.dart';
import '../../domain/model/written_page.dart';
import '../../domain/repositories/page_repository.dart';
import '../dto/content_dto.dart';
import '../files/image_shrinker.dart';
import '../remote/page_api.dart';
import 'api_guard.dart';

class PageRepositoryImpl implements PageRepository {
  PageRepositoryImpl(this._api, this._config);

  final PageApi _api;
  final AppConfig _config;

  @override
  Future<WrittenPage> create(DocumentDraft draft) => guard(() async {
    final json = draftJson(draft)..remove('draft');
    return writtenPageOf(await _api.create(json), _config.apiBaseUrl);
  });

  @override
  Future<WrittenPage> page(String id) => guard(() async => writtenPageOf(await _api.page(id), _config.apiBaseUrl));

  @override
  Future<ContentDocument> save(String id, {required List<Map<String, dynamic>> body, required List<Map<String, dynamic>> answerBody}) =>
      guard(() async => documentOf(await _api.save(id, {'body': body, 'answerBody': answerBody})));

  @override
  Future<UploadedPicture> uploadPicture(PickedFile picture) => guard(() async {
    final ready = await shrinkPhoto(picture);
    final json = await _api.picture(ready.bytes, ready.name);
    return UploadedPicture(id: json['id'] as String, url: absoluteLink(_config.apiBaseUrl, json['url']));
  });
}
