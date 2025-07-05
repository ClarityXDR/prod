import * as React from 'react';
import { useState, useEffect } from 'react';
import { AadHttpClient, HttpClientResponse } from '@microsoft/sp-http';
import { Chart, registerables } from 'chart.js';
import styles from './KQLDashboard.module.scss';

Chart.register(...registerables);

export interface IKQLDashboardProps {
  defenderClient: AadHttpClient;
  sentinelClient: AadHttpClient;
  defenderWorkspaceId: string;
  sentinelWorkspaceId: string;
  refreshInterval: number;
  context: any;
}

interface SecurityMetrics {
  criticalAlerts: number;
  highAlerts: number;
  mediumAlerts: number;
  lowAlerts: number;
  totalIncidents: number;
  activeInvestigations: number;
}

export const KQLDashboard: React.FC<IKQLDashboardProps> = (props) => {
  const [metrics, setMetrics] = useState<SecurityMetrics>({
    criticalAlerts: 0,
    highAlerts: 0,
    mediumAlerts: 0,
    lowAlerts: 0,
    totalIncidents: 0,
    activeInvestigations: 0
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadSecurityData();
    const interval = setInterval(loadSecurityData, props.refreshInterval);
    return () => clearInterval(interval);
  }, []);

  const loadSecurityData = async () => {
    try {
      setLoading(true);
      
      // Query Defender XDR
      const defenderData = await queryDefenderXDR();
      
      // Query Sentinel
      const sentinelData = await querySentinel();
      
      // Combine metrics
      const combinedMetrics = combineMetrics(defenderData, sentinelData);
      setMetrics(combinedMetrics);
      
      setLoading(false);
    } catch (err) {
      setError(err.message);
      setLoading(false);
    }
  };

  const queryDefenderXDR = async () => {
    const query = `
      AlertInfo 
      | where Timestamp > ago(24h)
      | summarize Count = count() by Severity
    `;

    const response = await props.defenderClient.post(
      'https://api.security.microsoft.com/api/advancedhunting/run',
      AadHttpClient.configurations.v1,
      {
        body: JSON.stringify({ Query: query }),
        headers: {
          'Content-Type': 'application/json'
        }
      }
    );

    if (!response.ok) {
      throw new Error('Failed to query Defender XDR');
    }

    return await response.json();
  };

  const querySentinel = async () => {
    const query = `
      SecurityAlert
      | where TimeGenerated > ago(24h)
      | summarize Count = count() by AlertSeverity
    `;

    const response = await props.sentinelClient.post(
      `https://api.loganalytics.io/v1/workspaces/${props.sentinelWorkspaceId}/query`,
      AadHttpClient.configurations.v1,
      {
        body: JSON.stringify({ query }),
        headers: {
          'Content-Type': 'application/json'
        }
      }
    );

    if (!response.ok) {
      throw new Error('Failed to query Sentinel');
    }

    return await response.json();
  };

  const combineMetrics = (defenderData: any, sentinelData: any): SecurityMetrics => {
    // Process and combine data from both sources
    // This is a simplified example - real implementation would be more complex
    return {
      criticalAlerts: 5,
      highAlerts: 12,
      mediumAlerts: 28,
      lowAlerts: 45,
      totalIncidents: 90,
      activeInvestigations: 8
    };
  };

  const renderMetricCard = (title: string, value: number, severity: string) => {
    return (
      <div className={`${styles.metricCard} ${styles[severity]}`}>
        <div className={styles.metricValue}>{value}</div>
        <div className={styles.metricTitle}>{title}</div>
      </div>
    );
  };

  if (loading) {
    return <div className={styles.loading}>Loading security data...</div>;
  }

  if (error) {
    return <div className={styles.error}>Error: {error}</div>;
  }

  return (
    <div className={styles.kqlDashboard}>
      <h2 className={styles.title}>Security Operations Dashboard</h2>
      
      <div className={styles.metricsGrid}>
        {renderMetricCard('Critical Alerts', metrics.criticalAlerts, 'critical')}
        {renderMetricCard('High Alerts', metrics.highAlerts, 'high')}
        {renderMetricCard('Medium Alerts', metrics.mediumAlerts, 'medium')}
        {renderMetricCard('Low Alerts', metrics.lowAlerts, 'low')}
      </div>

      <div className={styles.summarySection}>
        <div className={styles.summaryCard}>
          <h3>Total Incidents</h3>
          <div className={styles.summaryValue}>{metrics.totalIncidents}</div>
        </div>
        <div className={styles.summaryCard}>
          <h3>Active Investigations</h3>
          <div className={styles.summaryValue}>{metrics.activeInvestigations}</div>
        </div>
      </div>

      <div className={styles.chartSection}>
        <canvas id="alertTrendChart"></canvas>
      </div>
    </div>
  );
};