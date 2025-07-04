import React, { Suspense, lazy } from 'react';
import { Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar';
import LoadingSpinner from './components/LoadingSpinner';
import './App.css';

// Lazy load pages for better performance
const HomePage = lazy(() => import('./pages/HomePage'));
const FeaturesPage = lazy(() => import('./pages/FeaturesPage'));
const ContactPage = lazy(() => import('./pages/ContactPage'));
const AgentsPage = lazy(() => import('./pages/AgentsPage'));
const AgentDetailPage = lazy(() => import('./pages/AgentDetailPage'));
const KQLPage = lazy(() => import('./pages/KQLPage'));
const ClientsPage = lazy(() => import('./pages/ClientsPage'));
const ClientDetailPage = lazy(() => import('./pages/ClientDetailPage'));
const RulesPage = lazy(() => import('./pages/RulesPage'));
const QueryResultsPage = lazy(() => import('./pages/QueryResultsPage'));
const DashboardPage = lazy(() => import('./pages/DashboardPage'));
const GitHubIssuesPage = lazy(() => import('./pages/GitHubIssuesPage'));
const GitHubIssueDetailPage = lazy(() => import('./pages/GitHubIssueDetailPage'));

function App() {
  return (
    <div className="app">
      <Navbar />
      <Suspense fallback={<div className="loading-container"><LoadingSpinner /></div>}>
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/features" element={<FeaturesPage />} />
          <Route path="/contact" element={<ContactPage />} />
          <Route path="/agents" element={<AgentsPage />} />
          <Route path="/agents/:agentId" element={<AgentDetailPage />} />
          <Route path="/kql" element={<KQLPage />} />
          <Route path="/kql/:clientId" element={<KQLPage />} />
          <Route path="/github-issues" element={<GitHubIssuesPage />} />
          <Route path="/github-issues/:issueId" element={<GitHubIssueDetailPage />} />
          <Route path="/clients" element={<ClientsPage />} />
          <Route path="/clients/:clientId" element={<ClientDetailPage />} />
          <Route path="/rules" element={<RulesPage />} />
          <Route path="/query-results/:queryId" element={<QueryResultsPage />} />
          <Route path="/dashboard" element={<DashboardPage />} />
        </Routes>
      </Suspense>
    </div>
  );
}

export default App;
