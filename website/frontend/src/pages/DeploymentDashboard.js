import React, { useState } from 'react';
import { Tabs, Tab, Container, Row, Col, Alert } from 'react-bootstrap';
import LogicAppDeployment from '../components/deployments/LogicAppDeployment';
import MDECustomRules from '../components/deployments/MDECustomRules';
import ThreatIntelligence from '../components/deployments/ThreatIntelligence';
import SentinelDeployment from '../components/deployments/SentinelDeployment';
import FutureModules from '../components/deployments/FutureModules';
import './DeploymentDashboard.css';

const DeploymentDashboard = () => {
  const [activeTab, setActiveTab] = useState('logic-apps');
  const [globalAlert, setGlobalAlert] = useState(null);

  const handleTabSelect = (key) => {
    setActiveTab(key);
    setGlobalAlert(null); // Clear alerts when switching tabs
  };

  return (
    <Container fluid className="deployment-dashboard">
      <Row>
        <Col>
          <h1 className="dashboard-title">Client Deployment Management</h1>
          <p className="dashboard-subtitle">
            Manage and deploy security solutions to client tenants
          </p>
        </Col>
      </Row>

      {globalAlert && (
        <Row className="mb-3">
          <Col>
            <Alert 
              variant={globalAlert.type} 
              dismissible 
              onClose={() => setGlobalAlert(null)}
            >
              {globalAlert.message}
            </Alert>
          </Col>
        </Row>
      )}

      <Row>
        <Col>
          <Tabs
            id="deployment-tabs"
            activeKey={activeTab}
            onSelect={handleTabSelect}
            className="deployment-tabs mb-4"
          >
            <Tab eventKey="logic-apps" title="Logic Apps">
              <LogicAppDeployment setGlobalAlert={setGlobalAlert} />
            </Tab>
            
            <Tab eventKey="mde-rules" title="MDE Custom Detection Rules">
              <MDECustomRules setGlobalAlert={setGlobalAlert} />
            </Tab>
            
            <Tab eventKey="threat-intel" title="Threat Intelligence">
              <ThreatIntelligence setGlobalAlert={setGlobalAlert} />
            </Tab>
            
            <Tab eventKey="sentinel" title="Sentinel V3 Deployment">
              <SentinelDeployment setGlobalAlert={setGlobalAlert} />
            </Tab>
            
            <Tab eventKey="future" title="Future Modules">
              <FutureModules />
            </Tab>
          </Tabs>
        </Col>
      </Row>
    </Container>
  );
};

export default DeploymentDashboard;
