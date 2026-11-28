# DEV_NOTES

- **سبب التلف:** أدّى انقطاع التيار الكهربائي (حدث Windows Kernel-Power 41 بتاريخ 2026-10-17 08:32:50) إلى عدم تفريغ المخازن المؤقتة للملفات، فتحوّل محتوى `apps/mobile/lib/screens.dart` (92935 بايت) و `apps/mobile/test/captain_documents_test.dart` (7236 بايت) إلى أصفار (NUL) بالكامل. تمّت الاستعادة بنجاح من لقطات opencode المخزّنة في مستودع snapshot كـ git blob.
- **الوقاية:** تفعيل الحفظ التلقائي للمحرر، وتكرار عمل `git commit` على فرع feature بدل ترك تغييرات كبيرة غير مثبّتة، والتحقّق من `git status` قبل إغلاق الجهاز.

## تأجيل: دخول جوجل

إعداد دخول Google مؤجل. عند استئناف العمل:

1. افتح Google Cloud Console واختر المشروع المرتبط بتطبيق Wasalny. من **IAM & Admin > Settings** سجّل **Project number** وتأكد أنه رقم المشروع المقصود، لا Project ID.
2. من **Google Auth Platform > Clients** استرجع OAuth Client ID الحالي من النوع **Web application**. إذا لم يكن موجودًا، أنشئ Web client جديدًا. لا تستخدم Client Secret في التطبيق أو في إعداد API.
3. أضف إلى **Authorized JavaScript origins** كلا العنوانين `http://localhost:5173` و`http://localhost`. لا تضف مسارات URL إلى قائمة origins.
4. من **Google Auth Platform > Audience** أضف حسابات المطورين إلى **Test users** إذا كان التطبيق في وضع Testing.
5. حدّث `GOOGLE_CLIENT_ID` في `apps/api/.env` إلى Web Client ID المختار، من دون تسجيل القيمة في logs أو إضافتها إلى Git.
6. شغّل Flutter Web مع Client ID نفسه: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1 --dart-define=GOOGLE_CLIENT_ID=<WEB_CLIENT_ID>`.
7. أعد تشغيل API وFlutter بعد تعديل الإعدادات، ثم اختبر حسابًا مسجلًا مسبقًا وحسابًا ضمن Test users. لا تشارك Client Secret أو أي token في البلاغات.

## قرار: لا ربط تلقائي لحساب Google بحساب موجود

`POST /auth/google` لا يربط `googleId` بحساب موجود بنفس البريد إذا كان لهذا الحساب كلمة مرور (`passwordHash`)، ويرفض الطلب بـ `409 EMAIL_USES_PASSWORD_LOGIN` دون كتابة أي شيء ودون إصدار جلسة. السبب: التسجيل لا يتحقق من ملكية البريد، فكان بإمكان طرف ثالث تسجيل بريد الضحية بكلمة مرور ثم ترك الضحية «يربط» Google فيبقى للمهاجم وصول بكلمة المرور (pre-hijacking). تُعرض الرسالة فقط بعد تحقق الخادم من توكن Google (`email_verified`)، فلا تكشف وجود الحساب لأي طرف غير موثّق.

الربط الآمن لاحقًا يتم من داخل الحساب بعد تسجيل الدخول بكلمة المرور (أو أي وسيلة يملكها المستخدم)، أو بعد إضافة تحقق فعلي من ملكية البريد الإلكتروني عند التسجيل؛ حينها يمكن السماح بالربط بثقة. الحسابات التي لا تملك أي وسيلة دخول أخرى (بلا كلمة مرور وبلا `googleId`) تبقى قابلة للربط لأن لا شيء يمكن للمهاجم الاستمرار به.

## Kashier webhook و Railway

مسار الـ webhook الفعلي هو `POST /api/v1/webhooks/kashier` داخل تطبيق API، ويُشغّل من Kashier كـ public endpoint لأن المصادقة تتم بتوقيع HMAC قبل أي معالجة. على Railway اضبط `KASHIER_WEBHOOK_URL` إلى `https://waslny-orders-production.up.railway.app/api/v1/webhooks/kashier` و`KASHIER_REDIRECT_URL` إلى `https://waslny-orders-production.up.railway.app/api/v1/payment-return` للرجوع إلى صفحة عامة تشرح للمستخدم أنه قد يعود للتطبيق. لا تستخدم redirect scheme مثل `myapp://` إلا إذا كان Kashier/مسار الرجوع يثبت دعم deep-link؛ التطبيق Mobile يملك مسار `/payment-redirect` على الواجهة، لكنه لا يحتاج تعديلًا في هذا الإعداد.

## Going live with Kashier

- `NODE_ENV=production`
- `KASHIER_BASE_URL=https://api.kashier.io`
- `KASHIER_MERCHANT_ID=<Live merchant ID>`
- `KASHIER_API_KEY=<Live Payment API Key>`
- `KASHIER_SECRET_KEY=<Live Secret Key>`
- `KASHIER_WEBHOOK_URL=https://waslny-orders-production.up.railway.app/api/v1/webhooks/kashier`
- `KASHIER_REDIRECT_URL=https://waslny-orders-production.up.railway.app/api/v1/payment-return`
- `KASHIER_AUTH_MERCHANT_ID=<optional multi-merchant ID>`
- `KASHIER_ALLOW_TEST_IN_PRODUCTION=false`

لا تخلط مفاتيح Test مع Live؛ مفاتيح Test تعمل فقط مع hosts الاختبار، ومفاتيح Live تعمل فقط مع hosts الـ Live. الرجوع إلى Test يكون بتغيير متغيرات Railway فقط إلى `https://test-api.kashier.io` ومفاتيح Test، مع إبقاء `.env` المحلي كما هو.

بعد النشر نفّذ شحن مبلغ صغير، وتأكد من وصول webhook واحد فقط، ومن تحديث الرصيد محلياً مرة واحدة فقط، ثم استرداد المبلغ وفق لوحة Kashier.

## Deploy admin on Railway

أنشئ خدمة Railway منفصلة مع **Root Directory** = `apps/admin`. الخدمة static Vite/React، وتستخدم `apps/admin/railway.json`: الأمر `npm install --include=dev --workspaces=false && npm run build` للبناء و`npm start` للتشغيل؛ خادم `sirv` يقدّم `dist` مع SPA fallback ويستمع على `0.0.0.0:$PORT`.

اضبط متغير Railway `VITE_API_URL=https://waslny-orders-production.up.railway.app/api/v1` قبل البناء؛ Vite يضمّنه في bundle وقت build، لذلك أعد النشر عند تغييره. هذا المتغير public فقط، ولا تضع فيه أسراراً أو مفاتيح. القيمة المحلية الافتراضية `http://localhost:3000/api/v1` تعمل في development فقط. واجهة المسارات تتحقق من الوصول عبر `/admin/dashboard` المحمي بـJWT ودور `ADMIN`، والـ API يفرض الحماية نفسه على كل endpoint إداري.

بعد إنشاء خدمة الأدمن، أضف origin العام الخاص بها إلى `CORS_ORIGINS` في خدمة API (أو استخدم `CLIENT_ORIGIN` إذا كان origin واحداً فقط)؛ وإلا سيمنع المتصفح طلبات الأدمن إلى API بسبب CORS.

## Building and distributing the Android APK

لا تنشئ keystore داخل المستودع. أنشئ واحداً محلياً بقيمك الخاصة، ولا تشارك كلمات المرور:

```sh
keytool -genkeypair -v -keystore apps/mobile/android/app/upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

انسخ `apps/mobile/android/key.properties.example` إلى `apps/mobile/android/key.properties`، ثم املأ `storeFile=app/upload-keystore.jks` و`storePassword=<store-password>` و`keyAlias=<key-alias>` و`keyPassword=<key-password>`. الملف وملفات keystore مستثناة من Git؛ بناء release يرفض الإكمال إذا كانت الخصائص أو ملف keystore ناقصة، ولا يستخدم debug signing.

ابنِ APK منفصلاً لكل ABI أو APK شاملاً، مع إمكانية تجاوز عنوان API:

```sh
cd apps/mobile
flutter build apk --release --split-per-abi
flutter build apk --release --dart-define=API_BASE_URL=https://waslny-orders-production.up.railway.app/api/v1
```

عنوان Railway أعلاه هو الافتراضي للـ release؛ كل override في release يجب أن يكون HTTPS وغير loopback. التطوير يبقى على `localhost` للويب و`10.0.2.2` لمحاكي Android. زد `version` في `pubspec.yaml` عند كل إصدار، خصوصاً `versionCode` بعد علامة `+`. استخدم دائماً keystore وalias نفسيهما للتحديثات اللاحقة؛ فقدانه يمنع تحديث التطبيق المثبت بنفس `applicationId`.

استخرج SHA-1 وSHA-256 من شهادة التوقيع ثم أضفهما إلى إعدادات Android OAuth في Google Cloud/Firebase:

```sh
keytool -list -v -keystore apps/mobile/android/app/upload-keystore.jks -alias <key-alias>
```

تحقق يدوياً أن `google-services.json` يطابق تطبيق Android ذي `applicationId` الحالي ومشروع Firebase المقصود. ملف Firebase المحلي الموجود مستثنى من Git؛ لا تضعه أو مفاتيح/كلمات مرور التوقيع في مستودع عام.
