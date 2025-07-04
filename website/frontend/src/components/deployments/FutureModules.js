import React from 'react';
import { Container, Row, Col, Card, Badge } from 'react-bootstrap';

const FutureModules = () => {
  const plannedModules = [
    {
      title: 'Microsoft Purview Integration',
      description: 'Automated deployment and configuration of Microsoft Purview for data governance and compliance',
      status: 'Planned',
      estimatedRelease: 'Q2 2025',
      features: ['Data classification', 'Compliance policies', 'DLP rules', 'Insider risk management']
    },
    {
      title: 'Azure Policy Deployment',
      description: 'Deploy and manage Azure Policy initiatives across client subscriptions',
      status: 'In Design',
      estimatedRelease: 'Q1 2025',
      features: ['Policy templates', 'Compliance reporting', 'Remediation tasks', 'Custom policies']
    },
    {
      title: 'Defender for Cloud Configuration',
      description: 'Automated setup and hardening of Microsoft Defender for Cloud',
      status: 'Planned',
      estimatedRelease: 'Q2 2025',
      features: ['Security recommendations', 'Regulatory compliance', 'Cloud security posture', 'Workload protection']
    },
    {
      title: 'Automated Incident Response',
      description: 'Deploy pre-configured incident response playbooks and automation',
      status: 'In Design',
      estimatedRelease: 'Q3 2025',
      features: ['Response playbooks', 'SOAR integration', 'Automated remediation', 'Incident metrics']
    },
    {
      title: 'Security Orchestration Hub',
      description: 'Central orchestration for all security tools and workflows',
      status: 'Concept',
      estimatedRelease: 'Q4 2025',
      features: ['Tool integration', 'Workflow designer', 'Custom connectors', 'Performance analytics']
    },
    {
      title: 'Compliance Automation Suite',
      description: 'Automated compliance checks and reporting for various frameworks',
      status: 'Planned',
      estimatedRelease: 'Q3 2025',
      features: ['SOC 2', 'ISO 27001', 'HIPAA', 'Custom frameworks']
    }
  ];

  const getStatusBadge = (status) => {
    const statusMap = {
      'Planned': 'primary',
      'In Design': 'info',
      'Concept': 'secondary',
      'Development': 'warning'
    };
    return <Badge bg={statusMap[status] || 'secondary'}>{status}</Badge>;
  };

  return (
    <div className="deployment-module">
      <div className="module-header">
        <h2 className="module-title">Future Modules</h2>
        <p className="text-muted">Upcoming deployment capabilities for ClarityXDR</p>
      </div>

      <Row>
        {plannedModules.map((module, index) => (
          <Col md={6} lg={4} key={index} className="mb-4">
            <Card className="h-100">
              <Card.Body>
                <div className="d-flex justify-content-between align-items-start mb-2">
                  <h5 className="card-title">{module.title}</h5>
                  {getStatusBadge(module.status)}
                </div>
                <p className="text-muted">{module.description}</p>
                <div className="mb-3">
                  <small className="text-muted">
                    <i className="bi bi-calendar3"></i> Target: {module.estimatedRelease}
                  </small>
                </div>
                <h6>Planned Features:</h6>
                <ul className="small">
                  {module.features.map((feature, idx) => (
                    <li key={idx}>{feature}</li>
                  ))}
                </ul>
              </Card.Body>
              <Card.Footer className="bg-light">
                <small className="text-muted">
                  <i className="bi bi-info-circle"></i> Contact us to prioritize this module
                </small>
              </Card.Footer>
            </Card>
          </Col>
        ))}
      </Row>

      <Card className="mt-4 bg-light">
        <Card.Body className="text-center">
          <h4>Have a module request?</h4>
          <p>We're always looking to expand our deployment capabilities based on customer needs.</p>
          <a href="mailto:features@clarityxdr.com" className="btn btn-primary">
            <i className="bi bi-envelope"></i> Submit Feature Request
          </a>
        </Card.Body>
      </Card>
    </div>
  );
};

export default FutureModules;
