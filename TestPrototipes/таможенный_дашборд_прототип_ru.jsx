import { useState, useEffect } from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Download, Info } from "lucide-react";
import { LineChart, Line, XAxis, YAxis, Tooltip, CartesianGrid, Legend, PieChart, Pie, Cell, ResponsiveContainer } from "recharts";
import { motion } from "framer-motion";

// -------------------------------------------------------------
// Прототип дашборда (визуализация в духе data.gov.ru)
// Все данные искусственные — только для демонстрации визуала и логики.
// Основной акцент — на блоке рекомендаций: данные призваны их обосновывать.
// -------------------------------------------------------------

function InfoButton({ text }: { text: string }) {
  return (
    <div className="relative inline-block select-none">
      <span
        className="peer inline-flex items-center justify-center w-7 h-7 rounded-full border border-blue-200 bg-blue-50 text-blue-700 hover:bg-blue-100 transition"
        aria-label="Подсказка"
      >
        <Info className="w-4 h-4" />
      </span>
      <div className="invisible peer-hover:visible opacity-0 peer-hover:opacity-100 transition-opacity absolute right-0 mt-2 z-20 w-80 p-3 bg-white text-gray-700 text-sm rounded-xl shadow-lg border">
        {text}
      </div>
    </div>
  );
}

export default function CustomsDashboardRU() {
  const [message, setMessage] = useState<string>("");

  // Искусственные данные (в условных единицах) — 2022–2024
  const dynamics = [
    { year: "2022", Импорт: 1200, Производство: 800, Потребление: 1800 },
    { year: "2023", Импорт: 1450, Производство: 950, Потребление: 2000 },
    { year: "2024", Импорт: 1600, Производство: 1100, Потребление: 2200 },
  ];

  // Географическая структура импорта (доли, %)
  const geo = [
    { name: "Китай", value: 45 },
    { name: "Германия", value: 25 },
    { name: "Италия", value: 15 },
    { name: "Турция", value: 10 },
    { name: "Прочие", value: 5 },
  ];

  // Средние контрактные цены (USD/т) — топ‑5 стран
  const avgPrices = [
    { name: "Китай", value: 120 },
    { name: "Германия", value: 140 },
    { name: "Италия", value: 130 },
    { name: "Турция", value: 115 },
    { name: "Южная Корея", value: 150 },
  ];

  // Разные насыщенные цвета для всех серий/сегментов
  const LINE_COLORS = { Импорт: "#D32F2F", Производство: "#2E7D32", Потребление: "#1565C0" } as const;
  const PIE_COLORS = ["#1565C0", "#2E7D32", "#F57C00", "#6A1B9A", "#D32F2F"]; // 5 разных оттенков

  const exportReport = (type: "pdf" | "word") => {
    setMessage(`Выгрузка справки в формате ${type.toUpperCase()} доступна в полном релизе. (Заглушка)`);
    setTimeout(() => setMessage(""), 3500);
  };

  // Быстрые расчёты для обоснования рекомендаций (демо)
  const importGrowth = Math.round(((dynamics[2].Импорт - dynamics[0].Импорт) / dynamics[0].Импорт) * 100);
  const prodGrowth = Math.round(((dynamics[2].Производство - dynamics[0].Производство) / dynamics[0].Производство) * 100);
  const consGrowth = Math.round(((dynamics[2].Потребление - dynamics[0].Потребление) / dynamics[0].Потребление) * 100);

  // --- Простые самопроверки ("тесты") для данных и расчётов ---
  useEffect(() => {
    try {
      // 1) Проверяем ростовые метрики
      if (importGrowth !== 33) console.warn("[TEST] importGrowth ожидается 33, получено:", importGrowth);
      if (prodGrowth !== 38) console.warn("[TEST] prodGrowth ожидается 38, получено:", prodGrowth);
      if (consGrowth !== 22) console.warn("[TEST] consGrowth ожидается 22, получено:", consGrowth);
      // 2) Сумма долей географии = 100
      const geoSum = geo.reduce((s, x) => s + x.value, 0);
      if (geoSum !== 100) console.warn("[TEST] Сумма долей geo должна быть 100, сейчас:", geoSum);
      // 3) Топ‑5 по ценам — ровно 5 стран
      if (avgPrices.length !== 5) console.warn("[TEST] avgPrices должен содержать 5 элементов, сейчас:", avgPrices.length);
      // 4) Палитры покрывают нужное количество и цвета уникальны
      if (PIE_COLORS.length < geo.length) console.warn("[TEST] Недостаточно цветов для GEO, сейчас:", PIE_COLORS.length);
      if (PIE_COLORS.length < avgPrices.length) console.warn("[TEST] Недостаточно цветов для avgPrices, сейчас:", PIE_COLORS.length);
      const uniquePie = new Set(PIE_COLORS);
      if (uniquePie.size !== PIE_COLORS.length) console.warn("[TEST] В PIE_COLORS есть повторяющиеся цвета.");
      const lineKeys = Object.keys(LINE_COLORS);
      ["Импорт", "Производство", "Потребление"].forEach(k => { if (!lineKeys.includes(k)) console.warn(`[TEST] В LINE_COLORS отсутствует ключ ${k}`); });
    } catch (e) {
      console.warn("[TEST] Ошибка выполнения самопроверок:", e);
    }
  }, []);

  // --- Состояние для правых панелей описания (данные как в тултипе) ---
  const [activeGeoIndex, setActiveGeoIndex] = useState<number | null>(null);
  const [activePriceIndex, setActivePriceIndex] = useState<number | null>(null);

  const activeGeo = activeGeoIndex !== null ? geo[activeGeoIndex] : null;
  const activePrice = activePriceIndex !== null ? avgPrices[activePriceIndex] : null;

  return (
    <div className="min-h-screen bg-[#f7f9fc] text-gray-900">
      {/* Шапка в духе государственных порталов */}
      <header className="w-full border-b bg-white">
        <div className="mx-auto max-w-7xl px-6 py-5 flex items-center justify-between">
          <div>
            <div className="text-xs uppercase tracking-wider text-gray-500">Государственные данные / Аналитика регулирования</div>
            <h1 className="text-2xl md:text-3xl font-bold text-[#0B3D91] mt-1">Дашборд по выбранному товару</h1>
          </div>
          {/* Кнопки экспорта в шапке удалены по ТЗ */}
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-6 py-6 space-y-6">
        {message && (
          <motion.div initial={{ opacity: 0, y: -6 }} animate={{ opacity: 1, y: 0 }} className="rounded-xl border bg-white p-4 text-sm text-blue-800">
            {message}
          </motion.div>
        )}

        {/* 1) Основная информация — строго первой */}
        <Card className="shadow-sm border-l-4 border-l-[#0B3D91]">
          <CardHeader className="relative flex items-start">
            <CardTitle className="text-xl pr-12">Информация о товаре</CardTitle>
            <div className="absolute top-4 right-4">
              <InfoButton text="Базовые реквизиты позиции: наименование, код ТН ВЭД, актуальная ставка и обязательства РФ в ВТО." />
            </div>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-[15px]">
              <div className="rounded-xl bg-[#f1f5fd] border border-[#e3ebff] p-4">
                <div className="text-gray-500 text-xs uppercase tracking-wide">Наименование товара</div>
                <div className="mt-1 text-lg font-medium">Поликарбонат гранулированный</div>
              </div>
              <div className="rounded-xl bg-[#f1f5fd] border border-[#e3ebff] p-4">
                <div className="text-gray-500 text-xs uppercase tracking-wide">Код ТН ВЭД</div>
                <div className="mt-1 text-lg font-medium">3907 40 000 0</div>
              </div>
              <div className="rounded-xl bg-[#f1f5fd] border border-[#e3ebff] p-4">
                <div className="text-gray-500 text-xs uppercase tracking-wide">Текущая ставка таможенной пошлины</div>
                <div className="mt-1 text-lg font-semibold">10%</div>
              </div>
              <div className="rounded-xl bg-[#f1f5fd] border border-[#e3ebff] p-4">
                <div className="text-gray-500 text-xs uppercase tracking-wide">Ставка по обязательствам РФ в ВТО</div>
                <div className="mt-1 text-lg font-semibold">8%</div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* 2) Рекомендации — сразу после основной информации (акцент) */}
        <Card className="shadow-sm border-l-4 border-l-emerald-600">
          <CardHeader className="relative flex items-start">
            <CardTitle className="text-xl pr-12">Рекомендации по регулированию</CardTitle>
            <div className="absolute top-4 right-4">
              <InfoButton text="Итоговая мера формируется на основе динамики рынка, соотношения потребления и производства, а также географии поставок." />
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="rounded-xl bg-emerald-50 border border-emerald-200 p-4">
              <div className="text-sm text-emerald-800">
                <b>Итоговая рекомендация:</b> сохранить базовую ставку <b>10%</b>, установить <b>коридор 8–10%</b> с механизмом оперативного пересмотра.
                При росте доли импорта в потреблении свыше <b>55%</b> — рассмотреть <b>тарифную квоту</b>: до порогового объёма — <b>8%</b>, сверх — <b>10%</b>.
              </div>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
              <div className="rounded-lg border bg-white p-3">
                <div className="text-gray-500">Рост импорта (2022→2024)</div>
                <div className="text-lg font-semibold">{importGrowth}%</div>
              </div>
              <div className="rounded-lg border bg-white p-3">
                <div className="text-gray-500">Рост производства (2022→2024)</div>
                <div className="text-lg font-semibold">{prodGrowth}%</div>
              </div>
              <div className="rounded-lg border bg-white p-3">
                <div className="text-gray-500">Рост потребления (2022→2024)</div>
                <div className="text-lg font-semibold">{consGrowth}%</div>
              </div>
            </div>
            <ul className="list-disc pl-5 text-sm text-gray-700">
              <li>Производство растёт сопоставимыми темпами с импортом, что позволяет избежать ужесточения.</li>
              <li>География поставок диверсифицирована (крупнейший поставщик ~45%), риск зависимости умеренный.</li>
              <li>Коридор ставок и тарифная квота создают предсказуемость для бизнеса и сдерживают ценовые пики.</li>
            </ul>
          </CardContent>
        </Card>

        {/* 3) Географическая структура импорта — круговая диаграмма + правая легенда цветов */}
        <Card className="shadow-sm border-l-4 border-l-[#0B3D91]">
          <CardHeader className="relative flex items-start">
            <CardTitle className="text-xl pr-12">Географическая структура импорта</CardTitle>
            <div className="absolute top-4 right-4">
              <InfoButton text="Доли стран‑поставщиков на российском рынке. Используется для оценки концентрации и рисков зависимости." />
            </div>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-gray-600 mb-3">Круговая диаграмма показывает долю каждой страны‑поставщика в общем объёме импорта выбранного товара. Наведите на сектор для точного значения. Справа расположена расшифровка цветов с указанием доли.</p>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 items-start">
              <div className="md:col-span-2 h-[300px]">
                <ResponsiveContainer>
                  <PieChart>
                    <Pie
                      data={geo}
                      dataKey="value"
                      nameKey="name"
                      outerRadius={110}
                      label
                      onMouseEnter={(_, idx) => setActiveGeoIndex(idx)}
                      onMouseLeave={() => setActiveGeoIndex(null)}
                    >
                      {geo.map((_, idx) => (
                        <Cell key={idx} fill={PIE_COLORS[idx % PIE_COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip formatter={(v: number) => `${v}%`} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
              <div className="rounded-xl border bg-white p-4">
                <div className="text-sm text-gray-500 mb-2">Легенда цветов</div>
                <div className="space-y-2">
                  {geo.map((g, i) => (
                    <div key={g.name} className={`flex items-center justify-between gap-3 ${activeGeoIndex === i ? "bg-gray-50" : ""} rounded px-2 py-1`}>
                      <div className="flex items-center gap-2">
                        <span className="inline-block w-3 h-3 rounded" style={{ backgroundColor: PIE_COLORS[i % PIE_COLORS.length] }} />
                        <span className="font-medium">{g.name}</span>
                      </div>
                      <span className="text-sm text-gray-600">{g.value}%</span>
                    </div>
                  ))}
                </div>
                {activeGeo && (
                  <div className="mt-3 text-xs text-gray-500">Навели: <b>{activeGeo.name}</b> — {activeGeo.value}%</div>
                )}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* 4) Объединённый график динамик — уникальные цвета, одинаковая толщина */}
        <Card className="shadow-sm border-l-4 border-l-[#0B3D91]">
          <CardHeader className="relative flex items-start">
            <CardTitle className="text-xl pr-12">Динамика: импорт, производство, потребление (3 года)</CardTitle>
            <div className="absolute top-4 right-4">
              <InfoButton text="Сравнение ключевых рядов на одном графике помогает быстро увидеть разрывы между спросом и предложением." />
            </div>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-gray-600 mb-3">Линии показывают изменение объёмов за 2022–2024 годы: импорт, производство и потребление. Сравнение на одном графике помогает увидеть дефицит или профицит на рынке.</p>
            <div className="w-full h-[360px]">
              <ResponsiveContainer>
                <LineChart data={dynamics} margin={{ top: 10, right: 20, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="year" tickMargin={8} />
                  <YAxis tickMargin={8} label={{ value: "тыс. т", angle: -90, position: "insideLeft" }} />
                  <Tooltip />
                  <Legend wrapperStyle={{ paddingTop: 8 }} />
                  <Line type="monotone" dataKey="Импорт" stroke={LINE_COLORS["Импорт"]} strokeWidth={3} activeDot={{ r: 6 }} />
                  <Line type="monotone" dataKey="Производство" stroke={LINE_COLORS["Производство"]} strokeWidth={3} activeDot={{ r: 6 }} />
                  <Line type="monotone" dataKey="Потребление" stroke={LINE_COLORS["Потребление"]} strokeWidth={3} activeDot={{ r: 6 }} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* 5) Средние контрактные цены (топ‑5) — круговая диаграмма + правая легенда цветов */}
        <Card className="shadow-sm border-l-4 border-l-[#0B3D91]">
          <CardHeader className="relative flex items-start">
            <CardTitle className="text-xl pr-12">Средние контрактные цены импорта (топ‑5 стран), USD/т</CardTitle>
            <div className="absolute top-4 right-4">
              <InfoButton text="Сопоставление ценовых уровней крупнейших поставщиков. Диаграмма носит справочный характер (демо)." />
            </div>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-gray-600 mb-3">Секторы пропорциональны уровню средней контрактной цены по стране; подписи отображают значение в USD/т (демо-данные). Справа расположена расшифровка цветов и значения по странам.</p>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 items-start">
              <div className="md:col-span-2 h-[300px]">
                <ResponsiveContainer>
                  <PieChart>
                    <Pie
                      data={avgPrices}
                      dataKey="value"
                      nameKey="name"
                      outerRadius={110}
                      label
                      onMouseEnter={(_, idx) => setActivePriceIndex(idx)}
                      onMouseLeave={() => setActivePriceIndex(null)}
                    >
                      {avgPrices.map((_, idx) => (
                        <Cell key={idx} fill={PIE_COLORS[idx % PIE_COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip formatter={(v: number) => `${v} USD/т`} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
              <div className="rounded-xl border bg-white p-4">
                <div className="text-sm text-gray-500 mb-2">Легенда цветов</div>
                <div className="space-y-2">
                  {avgPrices.map((g, i) => (
                    <div key={g.name} className={`flex items-center justify-between gap-3 ${activePriceIndex === i ? "bg-gray-50" : ""} rounded px-2 py-1`}>
                      <div className="flex items-center gap-2">
                        <span className="inline-block w-3 h-3 rounded" style={{ backgroundColor: PIE_COLORS[i % PIE_COLORS.length] }} />
                        <span className="font-medium">{g.name}</span>
                      </div>
                      <span className="text-sm text-gray-600">{g.value} USD/т</span>
                    </div>
                  ))}
                </div>
                {activePrice && (
                  <div className="mt-3 text-xs text-gray-500">Навели: <b>{activePrice.name}</b> — {activePrice.value} USD/т</div>
                )}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Кнопки экспорта — заглушки (оставлены внизу страницы) */}
        <div className="flex justify-end gap-3 pt-2">
          <Button onClick={() => exportReport("pdf")} className="rounded-2xl">
            <Download className="w-4 h-4 mr-2" /> Выгрузить PDF
          </Button>
          <Button variant="outline" onClick={() => exportReport("word")} className="rounded-2xl">
            <Download className="w-4 h-4 mr-2" /> Выгрузить Word
          </Button>
        </div>

        <p className="text-xs text-gray-500">
          * Данные и расчёты на странице являются демонстрационными. Итоговая мера не является нормативным актом.
        </p>
      </main>
    </div>
  );
}
