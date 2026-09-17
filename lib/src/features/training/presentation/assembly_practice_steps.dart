import 'package:flutter/widgets.dart';

import '../../../core/utils/locale_text.dart';
import 'training_tour_steps.dart';

const assemblyPracticeRoute = '/training/assembly';
const assemblyPracticeLessonId = 'assembly_practice';

/// Instructions for the production TracksScreen and its four-step wizard.
/// Action steps advance only when the actual next control becomes visible.
List<TrainingTourStep> assemblyPracticeSteps(BuildContext context) {
  String text(String ru, String zh) => tr(context, ru: ru, zh: zh);
  TrainingTourStep step(
    int index,
    String title,
    String body,
    String action,
    String target, {
    String? next,
    bool wait = true,
  }) => TrainingTourStep(
    lessonId: assemblyPracticeLessonId,
    lessonStep: index,
    title: title,
    body: body,
    action: action,
    route: assemblyPracticeRoute,
    targetId: target,
    advanceTargetId: next,
    waitForAction: wait,
    readyTargetId: const {
      3: 'assembly.wizard.ready.0',
      4: 'assembly.wizard.ready.1',
      5: 'assembly.wizard.ready.2',
    }[index],
    preparations: [
      if (index >= 2 && index <= 6) ...[
        if (index <= 3)
          TrainingTourPreparation(
            targetId: 'assembly.wizard.back-to-tariff',
            instruction: text(
              'Нажмите «Назад» в форме, чтобы вернуться к тарифу и описанию.',
              '点击表单中的“上一步”返回运价和商品描述。',
            ),
          ),
        for (var previous = 0; previous < index - 3 && previous < 3; previous++)
          TrainingTourPreparation(
            targetId: 'assembly.wizard.ready.$previous',
            instruction: text(
              'Параметры этого шага заполнены. Нажмите выделенную кнопку «Далее» в форме.',
              '当前步骤已填写，点击表单中高亮的“下一步”。',
            ),
          ),
        TrainingTourPreparation(
          targetId: 'assembly.goods-description',
          instruction: text(
            'Заполните описание: «Футболки, 2 шт.; носки, 3 пары». Затем нажмите «Далее» в форме.',
            '填写描述“短袖2件；袜子3双”，然后点击表单中的“下一步”。',
          ),
        ),
        TrainingTourPreparation(
          targetId: 'assembly.places',
          instruction: text(
            'Выберите «По возможности 1 место» и продолжите форму кнопкой «Далее».',
            '选择“尽可能一件”并点击表单中的“下一步”。',
          ),
        ),
        TrainingTourPreparation(
          targetId: 'assembly.packaging',
          instruction: text(
            'Выберите основную упаковку и нажмите «Далее» в форме.',
            '选择主要包装并点击表单中的“下一步”。',
          ),
        ),
        TrainingTourPreparation(
          targetId: 'assembly.submit',
          instruction: text(
            'Вы закрыли форму. Нажмите «Отправка на сборку», чтобы открыть её снова.',
            '您已关闭表单，点击“提交集运”重新打开。',
          ),
        ),
      ],
      if (index == 7)
        TrainingTourPreparation(
          targetId: 'tracks.view.selector',
          instruction: text(
            'Откройте переключатель вида списка и выберите «Сборки».',
            '打开列表类型选择器并选择“集运单”。',
          ),
        ),
    ],
  );
  return [
    step(
      0,
      text('Выберите две посылки на складе', '选择两个已入库包裹'),
      text(
        'Это обычный экран «Треки» с тестовыми посылками. Все действия в этом примере остаются на устройстве. Посылка в пути ещё недоступна для сборки.',
        '这是使用测试包裹的实际“运单”页面。本示例的所有操作仅保存在本机。运输中的包裹暂不能集运。',
      ),
      text(
        'Отметьте флажками обе посылки со статусом «На складе». После выбора появится кнопка отправки.',
        '勾选两个“已入库”包裹。选择后将显示提交按钮。',
      ),
      'tracks.selection',
      next: 'assembly.selection.multiple',
    ),
    step(
      1,
      text('Откройте создание сборки', '打开创建集运单'),
      text(
        'Выбранные треки попадут в одну сборку. Кнопка находится внизу списка.',
        '所选运单将加入同一个集运单。按钮位于列表下方。',
      ),
      text('Нажмите выделенную кнопку «Отправка на сборку».', '点击高亮的“提交集运”按钮。'),
      'assembly.submit',
      next: 'assembly.tariff',
    ),
    step(
      2,
      text('Тариф и страховка', '运价与保险'),
      text(
        'Открылась настоящая форма. В первом шаге выбирают тариф, описывают товары и при необходимости включают страховку с суммой в юанях. Здесь выбран тестовый тариф; это не действующее предложение.',
        '已打开实际表单。第一步选择运价、描述商品，并可开启保险、填写人民币金额。这里选中的是示例运价，并非实际报价。',
      ),
      text(
        'Посмотрите выбранный тариф. Для примера оставьте страховку выключенной и нажмите «Далее» в этой подсказке, чтобы перейти к описанию товаров.',
        '查看所选运价。本例保持保险关闭，点击此提示中的“下一步”查看商品描述。',
      ),
      'assembly.tariff',
      wait: false,
    ),
    step(
      3,
      text('Заполните описание товаров', '填写商品描述'),
      text(
        'У одной тестовой посылки не заполнен товар. Поэтому выбранный тариф требует общее описание. Настоящая проверка формы не даст перейти дальше с пустым полем.',
        '一个测试包裹缺少商品信息，因此当前运价要求填写整体描述。实际表单校验会阻止空白提交。',
      ),
      text(
        'Введите «Футболки, 2 шт.; носки, 3 пары». Затем нажмите «Далее» внизу формы.',
        '输入“短袖2件；袜子3双”，然后点击表单底部的“下一步”。',
      ),
      'assembly.goods-description',
      next: 'assembly.places',
    ),
    step(
      4,
      text('Укажите параметры груза и места', '设置货物与件数'),
      text(
        'Во втором шаге отмечают хрупкие товары, выбирают снятие упаковки и количество мест. Для одежды в примере оставьте хрупкость и снятие упаковки без изменений.',
        '第二步设置易碎品、拆除包装和件数。本例为服装，请保持易碎与拆包设置不变。',
      ),
      text(
        'Выберите «По возможности 1 место» и нажмите «Далее» внизу формы.',
        '选择“一件”并点击表单底部的“下一步”。',
      ),
      'assembly.places',
      next: 'assembly.packaging',
    ),
    step(
      5,
      text('Выберите упаковку', '选择包装'),
      text(
        'В третьем шаге выбирают основную упаковку. Дополнительная защита добавляется отдельно при необходимости.',
        '第三步选择主要包装。需要时可另加防护材料。',
      ),
      text(
        'Нажмите на тестовую коробку. После выбора основной упаковки нажмите «Далее» внизу формы.',
        '点击示例纸箱。选好主要包装后，点击表单底部的“下一步”。',
      ),
      'assembly.packaging',
      next: 'assembly.review',
    ),
    step(
      6,
      text('Проверьте и отправьте учебную сборку', '核对并提交练习集运单'),
      text(
        'Это заключительный шаг настоящего мастера. Сверьте два выбранных трека, описание, тариф, место, упаковку и страховку. При ошибке используйте «Назад» в форме.',
        '这是实际向导的最后一步。核对两个运单、描述、运价、件数、包装和保险。如需修改，请使用表单中的“上一步”。',
      ),
      text(
        'После проверки нажмите «Отправить на сборку». В этом примере кнопка создаст только локальную тестовую сборку.',
        '核对后点击“提交集运”。本示例中此按钮仅创建本地测试集运单。',
      ),
      'assembly.review',
    ),
    step(
      7,
      text('Найдите созданную сборку', '查找已创建的集运单'),
      text(
        'После отправки выбранные посылки переходят из одиночных треков в сборки. Учебная сборка уже создана локально.',
        '提交后，所选包裹从单独运单移入集运列表。练习集运单已在本地创建。',
      ),
      text('Переключите список на «Сборки».', '将列表切换为“集运单”。'),
      'tracks.view.groups',
      next: 'assembly.open',
    ),
    step(
      8,
      text('Откройте результат', '打开集运结果'),
      text(
        'В списке появилась сборка с учебным номером. Здесь же в обычной работе находятся ваши отправленные сборки.',
        '列表中已出现带有练习编号的集运单。实际提交的集运单也显示在这里。',
      ),
      text('Нажмите выделенный номер сборки.', '点击高亮的集运单号。'),
      'assembly.open',
      next: 'assembly.tab.main',
    ),
    step(
      9,
      text('Проверьте статус сборки', '查看集运状态'),
      text(
        'Вы открыли обычную карточку сборки: статус и параметры находятся в «Основное», выбранные посылки — во вкладке «Треки». Склад ещё не упаковал груз, поэтому реальные места, фото и видео появятся позже.',
        '您已打开实际集运详情：“基本信息”中有状态和参数，“运单”中有所选包裹。仓库尚未打包，实际件数、照片和视频将稍后出现。',
      ),
      text(
        'Проверьте учебный результат и нажмите «Далее» в подсказке для завершения.',
        '查看练习结果后，点击提示中的“下一步”完成练习。',
      ),
      'assembly.status.details',
      wait: false,
    ),
  ];
}
