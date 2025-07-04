import React, { useEffect, useRef } from 'react';

const ParticlesBackground = ({ isAnimated = true }) => {
  const particlesRef = useRef(null);

  useEffect(() => {
    if (typeof window !== 'undefined' && window.tsParticles) {
      const loadParticles = async () => {
        try {
          await window.tsParticles.load("particles-js", {
            background: {
              color: {
                value: "transparent",
              },
            },
            fpsLimit: isAnimated ? 120 : 30,
            interactivity: {
              events: {
                onClick: {
                  enable: isAnimated,
                  mode: "push",
                },
                onHover: {
                  enable: isAnimated,
                  mode: "repulse",
                },
                resize: true,
              },
              modes: {
                push: {
                  quantity: 4,
                },
                repulse: {
                  distance: 200,
                  duration: 0.4,
                },
              },
            },
            particles: {
              color: {
                value: "#7CDB46",
              },
              links: {
                color: "#7CDB46",
                distance: 150,
                enable: true,
                opacity: 0.5,
                width: 1,
              },
              collisions: {
                enable: true,
              },
              move: {
                direction: "none",
                enable: isAnimated,
                outModes: {
                  default: "bounce",
                },
                random: false,
                speed: isAnimated ? 2 : 0.5,
                straight: false,
              },
              number: {
                density: {
                  enable: true,
                  area: 800,
                },
                value: isAnimated ? 80 : 40,
              },
              opacity: {
                value: 0.5,
              },
              shape: {
                type: "circle",
              },
              size: {
                value: { min: 1, max: 5 },
              },
            },
            detectRetina: true,
          });
        } catch (error) {
          console.warn('Failed to load particles:', error);
        }
      };

      // Check if tsParticles is loaded, if not, wait a bit
      if (window.tsParticles) {
        loadParticles();
      } else {
        const checkTsParticles = setInterval(() => {
          if (window.tsParticles) {
            clearInterval(checkTsParticles);
            loadParticles();
          }
        }, 100);

        // Clear interval after 5 seconds to avoid infinite loop
        setTimeout(() => clearInterval(checkTsParticles), 5000);
      }
    }
  }, [isAnimated]);

  return <div ref={particlesRef}></div>;
};

export default ParticlesBackground;