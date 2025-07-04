import React, { useState, useEffect } from 'react';
import ParticlesBackground from '../components/ParticlesBackground';
import './HomePage.css';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';

const HomePage = () => {
  const [threatCount, setThreatCount] = useState(1542);
  const [query, setQuery] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    // Get initial threat count from backend
    axios.get('/api/threats/count')
      .then(response => {
        if (response.data && response.data.count) {
          setThreatCount(response.data.count);
        }
      })
      .catch(error => console.error("Error fetching threat count:", error));

    // Update threat count periodically
    const interval = setInterval(() => {
      setThreatCount(prev => prev + Math.ceil(Math.random() * 5));
    }, 800 + Math.random() * 1200);

    return () => clearInterval(interval);
  }, []);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (query.trim()) {
      setIsLoading(true);
      
      axios.post('/api/queries', { query: query.trim() })
        .then(response => {
          console.log("Query submitted:", response.data);
          // Redirect to the results page
          navigate(`/query-results/${response.data.id}`);
        })
        .catch(error => {
          console.error("Error submitting query:", error);
          setIsLoading(false);
        });
    }
  };

  return (
    <>
      <div id="particles-js">
        <ParticlesBackground isAnimated={true} />
      </div>
      <div className="count-particles">
        <span className="js-count-particles">--</span> particles
      </div>
      <div className="main" id="hero">
        <div className="hero-wrapper">
          <div className="hero-logo">
            <img src="https://raw.githubusercontent.com/DataGuys/ClarityXDR/main/brand-assets/Icon_512x512.png" alt="ClarityXDR Logo" />
          </div>
          <div className="hero-title">
            <span className="brand">Clarity</span><span className="xdr">XDR</span>
            <span className="line1">Architected by Humans</span>
            <span className="line2">Operated by AI and ML</span>
          </div>
          <div className="hero-sub">
            Find clarity in chaos — transform Defender XDR into a mature, AI-driven SOC overnight.
          </div>
          <form onSubmit={handleSubmit}>
            <div className="hero-input">
              <input 
                type="text" 
                placeholder="Ask your security question..." 
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                disabled={isLoading}
              />
            </div>
            <div className="ctas">
              <a className="btn btn-secondary" href="/features">Explore Features</a>
              <button type="submit" className="btn btn-primary" disabled={isLoading}>
                {isLoading ? 'Processing...' : 'Get Started'}
              </button>
            </div>
          </form>
          <div className="ticker">
            Threats analyzed this hour: <span id="threat-count">{threatCount.toLocaleString()}</span>
          </div>
        </div>
        <footer>&copy; 2025 ClarityXDR. All rights reserved.</footer>
      </div>
    </>
  );
};

export default HomePage;
