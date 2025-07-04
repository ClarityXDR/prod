import React, { useCallback } from 'react';
import Particles from 'react-particles';
import { loadFull } from 'tsparticles';

const ParticlesBackground = ({ isAnimated = true }) => {
  const particlesInit = useCallback(async (engine) => {
    // Load full tsparticles bundle
    await loadFull(engine);
  }, []);

  const particlesLoaded = useCallback(async (container) => {
    console.log("Particles container loaded", container);
  }, []);

  const particlesOptions = {
    fpsLimit: 60,
    particles: {
      number: {
        value: window.innerWidth < 768 ? 30 : 50, // Responsive particle count
        density: { 
          enable: true, 
          area: 800 
        }
      },
      color: { 
        value: "#7CDB46" // Lime green from brand colors
      },
      links: {
        color: "#7CDB46",
        distance: 150,
        enable: true,
        opacity: 0.5,
        width: 1
      },
      move: {
        direction: "none",
        enable: isAnimated,
        speed: 2,
        outModes: { 
          default: "bounce" 
        }
      },
      opacity: {
        value: 0.5
      },
      shape: {
        type: "circle"
      },
      size: {
        value: { min: 1, max: 5 }
      }
    },
    interactivity: {
      events: {
        onHover: {
          enable: true,
          mode: "repulse"
        },
        onClick: {
          enable: true,
          mode: "push"
        },
        resize: true
      },
      modes: {
        repulse: {
          distance: 200,
          duration: 0.4
        },
        push: {
          quantity: 4
        }
      }
    },
    detectRetina: true,
    background: {
      color: "#0A0E23" // Dark blue background
    }
  };

  return (
    <Particles
      id="tsparticles"
      init={particlesInit}
      loaded={particlesLoaded}
      options={particlesOptions}
      style={{
        position: "absolute",
        width: "100%",
        height: "100%",
        zIndex: 1
      }}
    />
  );
};

export default ParticlesBackground;