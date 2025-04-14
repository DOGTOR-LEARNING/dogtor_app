<div className="card-title">
  <Icon name="chart-line" />
  本週學習趨勢
</div>

{weeklyStats.this_week.map((day, index) => (
  <div key={index} className="weekly-chart-point">
    <span className="chart-value">{day.levels}</span>
  </div>
))}

<div className="chart-tabs">
  <button className="active">本週</button>
</div>

<div className="knowledge-mastery">
  <div className="card-title">
    <Icon name="brain" />
    知識掌握度
  </div>
  
  {Object.entries(groupKnowledgePointsBySubject(knowledgeScores)).map(([subject, points]) => (
    <div key={subject} className="subject-knowledge">
      <h3 className="subject-title">{subject}</h3>
      <div className="knowledge-radar-chart">
        <RadarChart 
          data={formatDataForRadarChart(points)}
          options={radarChartOptions}
        />
      </div>
    </div>
  ))}
</div>

function groupKnowledgePointsBySubject(points) {
  const grouped = {};
  
  points.forEach(point => {
    if (!grouped[point.subject]) {
      grouped[point.subject] = [];
    }
    grouped[point.subject].push(point);
  });
  
  return grouped;
}

function formatDataForRadarChart(points) {
  return {
    labels: points.map(p => p.point_name),
    datasets: [{
      data: points.map(p => p.score),
    }]
  };
} 