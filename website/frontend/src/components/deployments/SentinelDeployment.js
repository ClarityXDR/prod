import React, { useState, useEffect } from 'react';
import { Card, Table, Alert, Button, Row, Col } from 'react-bootstrap';
import { fetchDeploymentData, deploySentinel } from '../../../api'; // Adjust the import based on your file structure
import './SentinelDeployment.css';

const SentinelDeployment = ({ setGlobalAlert }) => {
  const [deploymentData, setDeploymentData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const getData = async () => {
      try {
        const data = await fetchDeploymentData('sentinel');
        setDeploymentData(data);
      } catch (error) {
        setGlobalAlert({ type: 'danger', message: 'Error fetching deployment data' });
      } finally {
        setLoading(false);
      }
    };

    getData();
  }, [setGlobalAlert]);

  const handleDeploy = async () => {
    setLoading(true);
    try {
      await deploySentinel();
      setGlobalAlert({ type: 'success', message: 'Sentinel deployed successfully' });
    } catch (error) {
      setGlobalAlert({ type: 'danger', message: 'Error deploying Sentinel' });
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div>Loading...</div>;
  }

  if (!deploymentData) {
    return <div>No deployment data available</div>;
  }

  const { deploymentConfig } = deploymentData;

  return (
    <div className="sentinel-deployment">
      <Row>
        <Col>
          <h2>Sentinel V3 Deployment</h2>
          <p>Estimate your deployment costs and configure settings for Sentinel.</p>
        </Col>
      </Row>

      <Row>
        <Col md={8}>
          <Card className="mb-4">
            <Card.Body>
              <h5>Deployment Configuration</h5>
              <Table>
                <tbody>
                  <tr>
                    <td>Daily Quota (GB):</td>
                    <td className="text-end">{deploymentConfig.dailyQuotaGb}</td>
                  </tr>
                  <tr>
                    <td>Retention Period (days):</td>
                    <td className="text-end">{deploymentConfig.retentionDays}</td>
                  </tr>
                  <tr className="fw-bold">
                    <td>Total Estimate:</td>
                    <td className="text-end">
                      ~${(deploymentConfig.dailyQuotaGb * 4.3 + 5).toFixed(2)}/day
                    </td>
                  </tr>
                </tbody>
              </Table>
              <Alert variant="info">
                <small>Actual costs may vary based on usage and selected Azure region.</small>
              </Alert>
            </Card.Body>
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default SentinelDeployment;