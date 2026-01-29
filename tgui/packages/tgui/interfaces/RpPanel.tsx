import { useEffect, useRef, useState } from 'react';
import {
  Box,
  Button,
  Collapsible,
  Divider,
  Dropdown,
  Icon,
  Input,
  Modal,
  NoticeBox,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import { decodeHtmlEntities } from 'tgui-core/string';

import { useBackend } from '../backend';
import { Window } from '../layouts';

// Typing dots animation component
const TypingDots = () => {
  const [dotCount, setDotCount] = useState(1);

  useEffect(() => {
    const interval = setInterval(() => {
      setDotCount((prev) => (prev >= 3 ? 1 : prev + 1));
    }, 500);
    return () => clearInterval(interval);
  }, []);

  const dots = '.'.repeat(dotCount);
  return <Box as="span">{dots}</Box>;
};

type Participant = {
  name: string;
  ref: string;
  headshot: string;
  is_typing?: boolean;
};

type Message = {
  name: string;
  message: string;
  ref?: string;
  headshot: string;
  mode: string;
  timestamp?: string;
};

type VerbModeParticipant = {
  name: string;
  ref: string;
  categories: string[];
  interactions: Record<string, string[]>;
  descriptions: Record<string, string>;
  colors: Record<string, string>;
  block_interact: boolean;
  lewd_slots?: LewdSlot[];
};

type LewdSlot = {
  slot: string;
  name: string;
  img?: string;
};

type SelectedParticipant = {
  name: string;
  ref: string;
  headshot: string;
  details?: string[];
  pleasure?: number;
  arousal?: number;
  pain?: number;
  is_self?: boolean;
  erp_status_display?: string;
  hypno_status_display?: string;
  vore_status_display?: string;
  noncon_status_display?: string;
  erp_mechanics_display?: string;
  erp_status_depraved_display?: string;
  erp_status_violent_display?: string;
} | null;

type RpPanelData = {
  approach_mode: string;
  submissive_mode?: string;
  emote_mode: string;
  emote_modes: Record<string, string>;
  participants: Participant[];
  available_players: Participant[];
  messages: Message[];
  verb_mode_data: VerbModeParticipant | null;
  typing_participants?: string[];
  selected_participant?: SelectedParticipant;
  self_preferences?: {
    erp_status?: string;
    erp_status_nc?: string;
    erp_status_v?: string;
    erp_status_hypno?: string;
    erp_status_depraved?: string;
    erp_status_violent?: string;
    erp_status_mechanics?: string;
    genitals?: Array<{
      slot: string;
      name: string;
      visibility: number;
    }>;
    hide_underwear?: boolean;
    hide_bra?: boolean;
    hide_undershirt?: boolean;
    hide_socks?: boolean;
  } | null;
  show_erp_approaches?: boolean;
  theme?: string;
  sound_message_enabled?: boolean;
  sound_join_enabled?: boolean;
  sound_leave_enabled?: boolean;
  soundpack?: string;
  volume_message?: number;
  volume_join?: number;
  volume_leave?: number;
};

const MAX_MESSAGE_LENGTH = 2000;

export const RpPanel = (props) => {
  const { act, data } = useBackend<RpPanelData>();
  const {
    approach_mode = 'neutral',
    submissive_mode = 'dominant',
    emote_mode,
    emote_modes,
    participants = [],
    available_players = [],
    messages = [],
    verb_mode_data = null,
    selected_participant = null,
    self_preferences = null,
    show_erp_approaches = true,
    theme = 'default',
    sound_message_enabled = true,
    sound_join_enabled = true,
    sound_leave_enabled = true,
    soundpack = 'default',
    volume_message = 50,
    volume_join = 50,
    volume_leave = 50,
    autocum_enabled = false,
  } = data;

  // Fix dropdown z-index and backdrop overlay when Manage Self modal is open
  // Modal uses z-index: 1001, so dropdowns need to be higher
  // Also ensure backdrop covers full scrollable area
  useEffect(() => {
    if (!showManageSelf) {
      // Clean up any existing backdrop fixes when modal closes
      const existingStyle = document.getElementById(
        'rp-panel-manage-self-backdrop-fix',
      );
      if (existingStyle) {
        existingStyle.remove();
      }
      return;
    }

    const style = document.createElement('style');
    style.id = 'rp-panel-manage-self-dropdown-fix';
    style.textContent = `
      .Modal {
        z-index: 1001 !important;
      }
      .Dropdown__menu--wrapper {
        z-index: 1002 !important;
      }
    `;
    document.head.appendChild(style);

    // Fix backdrop to cover full scrollable area
    const backdropStyle = document.createElement('style');
    backdropStyle.id = 'rp-panel-manage-self-backdrop-fix';
    backdropStyle.textContent = `
      /* Target all possible backdrop elements */
      body > div[style*="position"][style*="fixed"],
      body > div[style*="z-index"],
      #root > div[style*="position"][style*="fixed"],
      #root > div[style*="z-index"] {
        position: fixed !important;
        top: 0 !important;
        left: 0 !important;
        right: 0 !important;
        bottom: 0 !important;
        width: 100vw !important;
        height: 100vh !important;
        min-height: 100vh !important;
        max-height: none !important;
      }
      /* More specific: target backdrop-like elements that are siblings to Modal */
      .Modal ~ div,
      div[class*="backdrop"],
      div[class*="overlay"],
      div[class*="dimmer"] {
        position: fixed !important;
        top: 0 !important;
        left: 0 !important;
        right: 0 !important;
        bottom: 0 !important;
        width: 100vw !important;
        height: 100vh !important;
        min-height: 100vh !important;
        max-height: none !important;
      }
    `;
    document.head.appendChild(backdropStyle);

    // Also try to find and fix backdrop elements directly
    const fixBackdrop = () => {
      // Look for backdrop elements (usually divs with specific styling)
      const allDivs = document.querySelectorAll('body > div, #root > div');
      allDivs.forEach((div) => {
        const style = window.getComputedStyle(div);
        // Check if this looks like a backdrop (fixed position, covers viewport, has background)
        if (
          (style.position === 'fixed' || style.position === 'absolute') &&
          (style.zIndex === '1000' ||
            style.zIndex === '1001' ||
            parseInt(style.zIndex) >= 1000) &&
          style.backgroundColor !== 'transparent' &&
          style.backgroundColor !== 'rgba(0, 0, 0, 0)'
        ) {
          (div as HTMLElement).style.position = 'fixed';
          (div as HTMLElement).style.top = '0';
          (div as HTMLElement).style.left = '0';
          (div as HTMLElement).style.right = '0';
          (div as HTMLElement).style.bottom = '0';
          (div as HTMLElement).style.width = '100vw';
          (div as HTMLElement).style.height = '100vh';
          (div as HTMLElement).style.minHeight = '100vh';
        }
      });
    };

    // Fix immediately and also on scroll/resize
    fixBackdrop();
    const interval = setInterval(fixBackdrop, 100);
    const scrollHandler = () => fixBackdrop();
    window.addEventListener('scroll', scrollHandler, true);
    window.addEventListener('resize', scrollHandler);

    return () => {
      const existingStyle = document.getElementById(
        'rp-panel-manage-self-dropdown-fix',
      );
      if (existingStyle) {
        existingStyle.remove();
      }
      const existingBackdropStyle = document.getElementById(
        'rp-panel-manage-self-backdrop-fix',
      );
      if (existingBackdropStyle) {
        existingBackdropStyle.remove();
      }
      clearInterval(interval);
      window.removeEventListener('scroll', scrollHandler, true);
      window.removeEventListener('resize', scrollHandler);
    };
  }, [showManageSelf]);

  // Apply theme styles to Section titles, buttons, and dividers
  useEffect(() => {
    const style = document.createElement('style');
    style.id = 'rp-panel-theme-styles';
    const titleColor = currentTheme.titleColor || currentTheme.color || '#fff';
    const buttonBackground = currentTheme.buttonBackground;
    const buttonText = currentTheme.buttonText || currentTheme.color || '#fff';
    const dividerColor = currentTheme.dividerColor || '#555';

    let css = `
      .Section__title {
        color: ${titleColor} !important;
      }
      .Divider {
        border-color: ${dividerColor} !important;
      }
    `;

    // Style buttons, but exclude attitude buttons (those inside .attitude-section)
    if (buttonBackground || buttonText) {
      css += `
        .Button:not(.Button--selected):not(.attitude-section .Button) {
          ${buttonBackground ? `background-color: ${buttonBackground} !important;` : ''}
          ${buttonText ? `color: ${buttonText} !important;` : ''}
        }
        .Button--selected:not(.attitude-section .Button) {
          ${buttonBackground ? `background-color: ${buttonText} !important;` : ''}
          ${buttonText ? `color: ${buttonBackground} !important;` : ''}
        }
      `;
    }

    style.textContent = css;
    document.head.appendChild(style);

    return () => {
      const existingStyle = document.getElementById('rp-panel-theme-styles');
      if (existingStyle) {
        existingStyle.remove();
      }
    };
  }, [currentTheme, theme]);

  const [showSettings, setShowSettings] = useState(false);
  const [showParticipantManagement, setShowParticipantManagement] =
    useState(false);
  const [showManageSelf, setShowManageSelf] = useState(false);

  const [messageInput, setMessageInput] = useState('');
  const inputRef = useRef(null);
  const messagesEndRef = useRef(null);
  const typingTimeoutRef = useRef(null);

  // Autofocus input when panel opens
  useEffect(() => {
    if (inputRef.current) {
      inputRef.current.focus();
    }
  }, []);

  // Autoscroll when new messages arrive (only if user is at bottom)
  const chatContainerRef = useRef(null);
  const [isAtBottom, setIsAtBottom] = useState(true);

  useEffect(() => {
    // Find the scrollable container (Section's scrollable content)
    const findScrollableContainer = () => {
      if (messagesEndRef.current) {
        let parent = messagesEndRef.current.parentElement;
        while (parent) {
          if (
            parent.classList.contains('Section__content') ||
            parent.scrollHeight > parent.clientHeight
          ) {
            chatContainerRef.current = parent;
            return parent;
          }
          parent = parent.parentElement;
        }
      }
      return null;
    };

    const container = findScrollableContainer();
    if (!container) return;

    const handleScroll = () => {
      const { scrollTop, scrollHeight, clientHeight } = container;
      const threshold = 50; // Allow 50px threshold
      setIsAtBottom(scrollHeight - scrollTop - clientHeight < threshold);
    };

    container.addEventListener('scroll', handleScroll);
    // Check initial state
    handleScroll();
    return () => container.removeEventListener('scroll', handleScroll);
  }, [messages.length]);

  const prevMessagesLength = useRef(messages.length);
  useEffect(() => {
    if (
      messages.length > prevMessagesLength.current &&
      isAtBottom &&
      messagesEndRef.current
    ) {
      setTimeout(() => {
        if (messagesEndRef.current) {
          messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
        }
      }, 0);
    }
    prevMessagesLength.current = messages.length;
  }, [messages.length, isAtBottom]);

  // Handle typing indicator
  useEffect(() => {
    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current);
    }

    if (messageInput && messageInput.trim()) {
      act('set_typing', { typing: true });
      typingTimeoutRef.current = setTimeout(() => {
        act('set_typing', { typing: false });
      }, 3000); // Stop typing after 3 seconds of inactivity
    } else {
      act('set_typing', { typing: false });
    }

    return () => {
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
      }
    };
  }, [messageInput, act]);

  const handleSendMessage = () => {
    if (!messageInput || !messageInput.trim()) {
      return;
    }
    act('send_message', { message: messageInput });
    setMessageInput('');
    // Refocus input after sending
    if (inputRef.current) {
      inputRef.current.focus();
    }
  };

  // Theme styles
  const themeStyles = {
    default: {
      backgroundColor: undefined,
      color: undefined,
      inputBackground: '#1e1e1e',
      inputBorder: '#555',
      inputText: '#fff',
      labelText: undefined, // Uses default label color
      statusBarBackground: '#1e1e1e',
      statusBarText: '#fff',
      titleColor: undefined, // Uses default title color
      buttonBackground: undefined, // Uses default button background
      buttonText: undefined, // Uses default button text
      dividerColor: '#555',
    },
    light: {
      backgroundColor: '#F5F5F5',
      color: '#1a1a1a',
      inputBackground: '#ffffff',
      inputBorder: '#ccc',
      inputText: '#1a1a1a',
      labelText: '#666',
      statusBarBackground: '#f0f0f0',
      statusBarText: '#1a1a1a',
      titleColor: '#1a1a1a',
      buttonBackground: '#e0e0e0',
      buttonText: '#1a1a1a',
      dividerColor: '#ccc',
    },
    cream: {
      backgroundColor: '#FFF8DC',
      color: '#3a3a3a',
      inputBackground: '#ffffff',
      inputBorder: '#d4c5a9',
      inputText: '#3a3a3a',
      labelText: '#5a5a5a',
      statusBarBackground: '#f5f0e0',
      statusBarText: '#3a3a3a',
      titleColor: '#3a3a3a',
      buttonBackground: '#e8dcc0',
      buttonText: '#3a3a3a',
      dividerColor: '#d4c5a9',
    },
    strawberry: {
      backgroundColor: '#FFD6D6',
      color: '#4a1a1a',
      inputBackground: '#ffffff',
      inputBorder: '#ffb3b3',
      inputText: '#4a1a1a',
      labelText: '#6a2a2a',
      statusBarBackground: '#ffe0e0',
      statusBarText: '#4a1a1a',
      titleColor: '#4a1a1a',
      buttonBackground: '#ffc0c0',
      buttonText: '#4a1a1a',
      dividerColor: '#ffb3b3',
    },
    super_dark: {
      backgroundColor: '#0a0a0a',
      color: '#e0e0e0',
      inputBackground: '#1a1a1a',
      inputBorder: '#444',
      inputText: '#e0e0e0',
      labelText: '#b0b0b0',
      statusBarBackground: '#1a1a1a',
      statusBarText: '#e0e0e0',
      titleColor: '#e0e0e0',
      buttonBackground: '#2a2a2a',
      buttonText: '#e0e0e0',
      dividerColor: '#444',
    },
    apple: {
      backgroundColor: '#FFE5E5',
      color: '#8B0000',
      inputBackground: '#ffffff',
      inputBorder: '#ff9999',
      inputText: '#8B0000',
      labelText: '#A00000',
      statusBarBackground: '#ffcccc',
      statusBarText: '#8B0000',
      titleColor: '#8B0000',
      buttonBackground: '#ffb3b3',
      buttonText: '#8B0000',
      dividerColor: '#ff9999',
    },
  };

  const currentTheme = themeStyles[theme] || themeStyles.default;

  return (
    <>
      {showSettings && (
        <Modal width="500px" style={{ zIndex: 1000 }}>
          <Section title="Settings">
            <Stack fill vertical>
              <Stack.Item>
                <Section title="Sound Settings">
                  <Stack fill vertical>
                    <Stack.Item>
                      <Button.Checkbox
                        fluid
                        checked={sound_message_enabled}
                        onClick={() => act('set_sound_message')}
                      >
                        Message Chime
                      </Button.Checkbox>
                    </Stack.Item>
                    <Stack.Item>
                      <Button.Checkbox
                        fluid
                        checked={sound_join_enabled}
                        onClick={() => act('set_sound_join')}
                      >
                        Participant Join Sound
                      </Button.Checkbox>
                    </Stack.Item>
                    <Stack.Item>
                      <Button.Checkbox
                        fluid
                        checked={sound_leave_enabled}
                        onClick={() => act('set_sound_leave')}
                      >
                        Participant Leave Sound
                      </Button.Checkbox>
                    </Stack.Item>
                  </Stack>
                </Section>
              </Stack.Item>
              <Stack.Item>
                <Section title="Volume Settings">
                  <Stack fill vertical>
                    <Stack.Item>
                      <Stack align="center">
                        <Stack.Item basis="200px">
                          Message Chime Volume:
                        </Stack.Item>
                        <Stack.Item grow>
                          <Input
                            type="number"
                            min="0"
                            max="100"
                            value={volume_message}
                            onInput={(e, value) => {
                              const numValue = parseInt(value, 10);
                              if (
                                !isNaN(numValue) &&
                                numValue >= 0 &&
                                numValue <= 100
                              ) {
                                act('set_volume_message', { volume: numValue });
                              }
                            }}
                          />
                        </Stack.Item>
                        <Stack.Item basis="50px" textAlign="center">
                          {volume_message}%
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>
                    <Stack.Item>
                      <Stack align="center">
                        <Stack.Item basis="200px">
                          Join Sound Volume:
                        </Stack.Item>
                        <Stack.Item grow>
                          <Input
                            type="number"
                            min="0"
                            max="100"
                            value={volume_join}
                            onInput={(e, value) => {
                              const numValue = parseInt(value, 10);
                              if (
                                !isNaN(numValue) &&
                                numValue >= 0 &&
                                numValue <= 100
                              ) {
                                act('set_volume_join', { volume: numValue });
                              }
                            }}
                          />
                        </Stack.Item>
                        <Stack.Item basis="50px" textAlign="center">
                          {volume_join}%
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>
                    <Stack.Item>
                      <Stack align="center">
                        <Stack.Item basis="200px">
                          Leave Sound Volume:
                        </Stack.Item>
                        <Stack.Item grow>
                          <Input
                            type="number"
                            min="0"
                            max="100"
                            value={volume_leave}
                            onInput={(e, value) => {
                              const numValue = parseInt(value, 10);
                              if (
                                !isNaN(numValue) &&
                                numValue >= 0 &&
                                numValue <= 100
                              ) {
                                act('set_volume_leave', { volume: numValue });
                              }
                            }}
                          />
                        </Stack.Item>
                        <Stack.Item basis="50px" textAlign="center">
                          {volume_leave}%
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>
                  </Stack>
                </Section>
              </Stack.Item>
              <Stack.Item />
              <Stack.Item>
                <Button fluid onClick={() => setShowSettings(false)}>
                  Close
                </Button>
              </Stack.Item>
            </Stack>
          </Section>
        </Modal>
      )}
      <Window
        width={1200}
        height={700}
        title="RP Panel"
        buttons={
          <Stack>
            <Stack.Item>
              <Dropdown
                options={[
                  { value: 'default', displayText: 'Default' },
                  { value: 'light', displayText: 'Light Mode' },
                  { value: 'cream', displayText: 'Cream' },
                  { value: 'strawberry', displayText: 'Strawberry' },
                  { value: 'super_dark', displayText: 'Super Dark' },
                  { value: 'apple', displayText: 'Apple' },
                ]}
                selected={theme || 'default'}
                onSelected={(value) => {
                  act('set_theme', { theme: value || 'default' });
                }}
              />
            </Stack.Item>
            <Stack.Item>
              <Dropdown
                options={[
                  { value: 'default', displayText: 'Default' },
                  { value: 'simpleandsweet', displayText: 'Simple and Sweet' },
                  { value: 'delicate', displayText: 'Delicate' },
                  { value: 'funkyou', displayText: 'Funk You' },
                  { value: 'gravitas', displayText: 'Gravitas' },
                  { value: '8bitautumn', displayText: '8-Bit Autumn' },
                ]}
                selected={soundpack || 'default'}
                onSelected={(value) => {
                  act('set_soundpack', { soundpack: value || 'default' });
                }}
              />
            </Stack.Item>
            <Stack.Item>
              <Button icon="cog" onClick={() => setShowSettings(true)} />
            </Stack.Item>
          </Stack>
        }
      >
        <Window.Content
          style={{
            ...currentTheme,
            'background-image': 'none',
          }}
        >
          <Stack fill>
            {/* Left Panel - Verbs/Interaction */}
            <Stack.Item width="400px">
              <Section fill scrollable>
                <Stack fill vertical>
                  <>
                    {/* Targeted Participant Headshot */}
                    <Stack.Item>
                      <Section
                        title={
                          <Stack>
                            <Stack.Item grow>Targeted Participant</Stack.Item>
                            <Stack.Item>
                              <Button
                                icon="cog"
                                onClick={() => setShowManageSelf(true)}
                              >
                                Manage Self
                              </Button>
                            </Stack.Item>
                          </Stack>
                        }
                      >
                        {selected_participant ? (
                          <Stack vertical>
                            {/* First row: Headshot and details */}
                            <Stack.Item>
                              <Stack>
                                <Stack.Item>
                                  {selected_participant.headshot ? (
                                    <img
                                      src={selected_participant.headshot}
                                      style={{
                                        width: '128px',
                                        height: '128px',
                                        'object-fit': 'cover',
                                        'border-radius': '4px',
                                      }}
                                    />
                                  ) : (
                                    <Box
                                      style={{
                                        width: '128px',
                                        height: '128px',
                                        'background-color': '#2a2a2a',
                                        border: '1px solid #555',
                                        'border-radius': '4px',
                                        display: 'flex',
                                        'align-items': 'center',
                                        'justify-content': 'center',
                                      }}
                                    >
                                      <Box color="label">No headshot</Box>
                                    </Box>
                                  )}
                                </Stack.Item>
                                <Stack.Item grow ml={1}>
                                  <Stack vertical>
                                    <Stack.Item>
                                      <Box bold fontSize="1.1em">
                                        {selected_participant.name}
                                      </Box>
                                    </Stack.Item>
                                    {selected_participant.details &&
                                      selected_participant.details.length >
                                        0 && (
                                        <Stack.Item>
                                          <Box
                                            style={{
                                              'border-left': '2px solid #555',
                                              'padding-left': '8px',
                                            }}
                                          >
                                            {selected_participant.details.map(
                                              (detail, index) => {
                                                // Bold keywords in details
                                                const keywords = [
                                                  'hands',
                                                  'barefoot',
                                                  'mouth',
                                                  'uncovered',
                                                  'covered',
                                                  'neutral',
                                                  'gentle',
                                                  'hard',
                                                  'rough',
                                                  'naked',
                                                  'topless',
                                                  'bottomless',
                                                  'penis',
                                                  'vagina',
                                                  'anus',
                                                  'breasts',
                                                  'testicles',
                                                  'socks',
                                                  'feet',
                                                ];
                                                let formattedDetail = detail;
                                                keywords.forEach((keyword) => {
                                                  const regex = new RegExp(
                                                    `\\b${keyword}\\b`,
                                                    'gi',
                                                  );
                                                  formattedDetail =
                                                    formattedDetail.replace(
                                                      regex,
                                                      (match) =>
                                                        `<b>${match}</b>`,
                                                    );
                                                });
                                                return (
                                                  <Box
                                                    key={index}
                                                    fontSize="0.9em"
                                                    mt={index > 0 ? 0.5 : 0}
                                                    dangerouslySetInnerHTML={{
                                                      __html: formattedDetail,
                                                    }}
                                                  />
                                                );
                                              },
                                            )}
                                          </Box>
                                        </Stack.Item>
                                      )}
                                  </Stack>
                                </Stack.Item>
                              </Stack>
                            </Stack.Item>
                            {/* Second row: Status Indicators - under headshot, full width */}
                            {selected_participant && (
                              <Stack.Item mt={1}>
                                <Stack fill>
                                  <Stack.Item grow basis={0}>
                                    <Stack vertical>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          style={{ textAlign: 'left' }}
                                        >
                                          ERP:
                                        </Box>
                                      </Stack.Item>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          bold
                                          style={{ textAlign: 'left' }}
                                        >
                                          {selected_participant.erp_status_display ||
                                            'NO'}
                                        </Box>
                                      </Stack.Item>
                                    </Stack>
                                  </Stack.Item>
                                  <Stack.Item grow basis={0}>
                                    <Stack vertical>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          style={{ textAlign: 'left' }}
                                        >
                                          HYPNOSIS:
                                        </Box>
                                      </Stack.Item>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          bold
                                          style={{ textAlign: 'left' }}
                                        >
                                          {selected_participant.hypno_status_display ||
                                            'NO'}
                                        </Box>
                                      </Stack.Item>
                                    </Stack>
                                  </Stack.Item>
                                  <Stack.Item grow basis={0}>
                                    <Stack vertical>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          style={{ textAlign: 'left' }}
                                        >
                                          VORE:
                                        </Box>
                                      </Stack.Item>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          bold
                                          style={{ textAlign: 'left' }}
                                        >
                                          {selected_participant.vore_status_display ||
                                            'NO'}
                                        </Box>
                                      </Stack.Item>
                                    </Stack>
                                  </Stack.Item>
                                  <Stack.Item grow basis={0}>
                                    <Stack vertical>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          style={{ textAlign: 'left' }}
                                        >
                                          NON-CON:
                                        </Box>
                                      </Stack.Item>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          bold
                                          style={{ textAlign: 'left' }}
                                        >
                                          {selected_participant.noncon_status_display ||
                                            'NO'}
                                        </Box>
                                      </Stack.Item>
                                    </Stack>
                                  </Stack.Item>
                                  <Stack.Item grow basis={0}>
                                    <Stack vertical>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          style={{ textAlign: 'left' }}
                                        >
                                          MECHANICS:
                                        </Box>
                                      </Stack.Item>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          bold
                                          style={{ textAlign: 'left' }}
                                        >
                                          {selected_participant.erp_mechanics_display ||
                                            'NONE'}
                                        </Box>
                                      </Stack.Item>
                                    </Stack>
                                  </Stack.Item>
                                  <Stack.Item grow basis={0}>
                                    <Stack vertical>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          style={{ textAlign: 'left' }}
                                        >
                                          DEPRAVED:
                                        </Box>
                                      </Stack.Item>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          bold
                                          style={{ textAlign: 'left' }}
                                        >
                                          {selected_participant.erp_status_depraved_display ||
                                            'NO'}
                                        </Box>
                                      </Stack.Item>
                                    </Stack>
                                  </Stack.Item>
                                  <Stack.Item grow basis={0}>
                                    <Stack vertical>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          style={{ textAlign: 'left' }}
                                        >
                                          VIOLENT:
                                        </Box>
                                      </Stack.Item>
                                      <Stack.Item>
                                        <Box
                                          fontSize="0.9em"
                                          bold
                                          style={{ textAlign: 'left' }}
                                        >
                                          {selected_participant.erp_status_violent_display ||
                                            'NO'}
                                        </Box>
                                      </Stack.Item>
                                    </Stack>
                                  </Stack.Item>
                                </Stack>
                              </Stack.Item>
                            )}
                          </Stack>
                        ) : (
                          <Box color="label" textAlign="center">
                            No participant selected
                          </Box>
                        )}
                      </Section>
                    </Stack.Item>

                    {/* Examine and Action Buttons */}
                    <Stack.Item>
                      <Section>
                        <Stack>
                          <Stack.Item grow>
                            <Button
                              fluid
                              icon="eye"
                              onClick={() => act('open_examine')}
                              disabled={!selected_participant}
                            >
                              Open Examine
                            </Button>
                          </Stack.Item>
                          <Stack.Item>
                            <Button
                              icon="image"
                              onClick={() => act('open_reference')}
                              disabled={!selected_participant}
                            >
                              Reference
                            </Button>
                          </Stack.Item>
                        </Stack>
                      </Section>
                    </Stack.Item>

                    {/* Participant Verb Target Dropdown */}
                    <Stack.Item>
                      <Section>
                        <Dropdown
                          width="100%"
                          selected={
                            selected_participant
                              ? selected_participant.name
                              : participants.length > 0
                                ? participants[0].name
                                : 'Select Participant'
                          }
                          options={[
                            { value: 'self', displayText: 'Self' },
                            ...participants.map((p) => ({
                              value: p.ref,
                              displayText: p.name,
                            })),
                          ]}
                          onSelected={(value) => {
                            if (value === 'self') {
                              act('set_selected_participant', { ref: null });
                            } else {
                              act('set_selected_participant', { ref: value });
                            }
                          }}
                        />
                      </Section>
                    </Stack.Item>

                    {/* Attitude Selector */}
                    <Stack.Item>
                      <div className="attitude-section">
                        <Section title="Attitude">
                          <Stack>
                            <Stack.Item grow>
                              <Button
                                fluid
                                color="green"
                                selected={approach_mode === 'gentle'}
                                onClick={() =>
                                  act('set_approach_mode', {
                                    approach: 'gentle',
                                  })
                                }
                                style={
                                  approach_mode === 'gentle'
                                    ? {
                                        'background-color': '#fff',
                                        color: '#000',
                                      }
                                    : {}
                                }
                              >
                                Gentle
                              </Button>
                            </Stack.Item>
                            <Stack.Item grow>
                              <Button
                                fluid
                                color="blue"
                                selected={approach_mode === 'neutral'}
                                onClick={() =>
                                  act('set_approach_mode', {
                                    approach: 'neutral',
                                  })
                                }
                                style={
                                  approach_mode === 'neutral'
                                    ? {
                                        'background-color': '#fff',
                                        color: '#000',
                                      }
                                    : {}
                                }
                              >
                                Neutral
                              </Button>
                            </Stack.Item>
                            <Stack.Item grow>
                              <Button
                                fluid
                                color="yellow"
                                selected={approach_mode === 'hard'}
                                onClick={() =>
                                  act('set_approach_mode', { approach: 'hard' })
                                }
                                style={
                                  approach_mode === 'hard'
                                    ? {
                                        'background-color': '#fff',
                                        color: '#000',
                                      }
                                    : {}
                                }
                              >
                                Hard
                              </Button>
                            </Stack.Item>
                            {show_erp_approaches !== false && (
                              <Stack.Item grow>
                                {(() => {
                                  const selfViolentEnabled =
                                    self_preferences?.erp_status_violent === 'Yes';
                                  // Check partner's violent preference only if a partner is selected (not self)
                                  const hasPartner =
                                    selected_participant &&
                                    !selected_participant.is_self;
                                  const partnerViolentEnabled = hasPartner
                                    ? selected_participant.erp_status_violent_display ===
                                        'YES'
                                    : true; // If no partner selected or it's self, don't check partner
                                  const isDisabled =
                                    !selfViolentEnabled || !partnerViolentEnabled;

                                  let tooltipText = '';
                                  if (isDisabled) {
                                    if (!selfViolentEnabled && !partnerViolentEnabled) {
                                      tooltipText =
                                        'Violent preference is turned off for both you and your partner';
                                    } else if (!selfViolentEnabled) {
                                      tooltipText =
                                        'Violent preference is turned off for you';
                                    } else {
                                      tooltipText =
                                        'Violent preference is turned off for your partner';
                                    }
                                  }

                                  return (
                                    <Button
                                      fluid
                                      color="red"
                                      selected={approach_mode === 'rough'}
                                      disabled={isDisabled}
                                      tooltip={tooltipText || undefined}
                                      onClick={() =>
                                        act('set_approach_mode', {
                                          approach: 'rough',
                                        })
                                      }
                                      style={
                                        approach_mode === 'rough'
                                          ? {
                                              'background-color': '#fff',
                                              color: '#000',
                                            }
                                          : {}
                                      }
                                    >
                                      Rough
                                    </Button>
                                  );
                                })()}
                              </Stack.Item>
                            )}
                          </Stack>
                        </Section>
                      </div>
                    </Stack.Item>

                    {/* Submissive/Dominant Mode Toggle */}
                    <Stack.Item>
                      <Section title="Mode">
                        <Stack>
                          <Stack.Item grow>
                            <Button
                              fluid
                              color={submissive_mode === 'dominant' ? 'blue' : 'default'}
                              selected={submissive_mode === 'dominant'}
                              onClick={() =>
                                act('set_submissive_mode', {
                                  mode: 'dominant',
                                })
                              }
                              style={
                                submissive_mode === 'dominant'
                                  ? {
                                      'background-color': '#4a9eff',
                                      color: '#fff',
                                    }
                                  : {}
                              }
                            >
                              Dominant
                            </Button>
                          </Stack.Item>
                          <Stack.Item grow>
                            <Button
                              fluid
                              color={submissive_mode === 'submissive' ? 'purple' : 'default'}
                              selected={submissive_mode === 'submissive'}
                              onClick={() =>
                                act('set_submissive_mode', {
                                  mode: 'submissive',
                                })
                              }
                              style={
                                submissive_mode === 'submissive'
                                  ? {
                                      'background-color': '#b366ff',
                                      color: '#fff',
                                    }
                                  : {}
                              }
                            >
                              Submissive
                            </Button>
                          </Stack.Item>
                        </Stack>
                      </Section>
                    </Stack.Item>

                    {/* Divider */}
                    <Stack.Item>
                      <Divider />
                    </Stack.Item>

                    {/* Verbs Panel */}
                    <Stack.Item grow>
                      <Section fill scrollable>
                        {verb_mode_data ? (
                          <Stack fill vertical>
                            {verb_mode_data.categories.length === 0 ? (
                              <Box
                                textAlign="center"
                                mt={2}
                                style={{
                                  color: currentTheme.labelText || undefined,
                                }}
                              >
                                No interactions available.
                              </Box>
                            ) : (
                              verb_mode_data.categories.map((category) => (
                                <Stack.Item key={category}>
                                  <Collapsible title={category}>
                                    <Section fill>
                                      <Box mt={0.2}>
                                        {verb_mode_data.interactions[
                                          category
                                        ]?.map((interaction) => (
                                          <Button
                                            key={interaction}
                                            width="150.5px"
                                            lineHeight={1.75}
                                            disabled={
                                              verb_mode_data.block_interact
                                            }
                                            color={
                                              verb_mode_data.block_interact
                                                ? 'grey'
                                                : verb_mode_data.colors[
                                                    interaction
                                                  ] || 'blue'
                                            }
                                            content={interaction}
                                            tooltip={
                                              verb_mode_data.descriptions[
                                                interaction
                                              ]
                                            }
                                            icon="exclamation-circle"
                                            onClick={() =>
                                              act('trigger_interaction', {
                                                interaction: interaction,
                                              })
                                            }
                                          />
                                        ))}
                                      </Box>
                                    </Section>
                                  </Collapsible>
                                </Stack.Item>
                              ))
                            )}
                          </Stack>
                        ) : (
                          <Box color="label" textAlign="center" mt={2}>
                            No participants with interactions available.
                          </Box>
                        )}
                      </Section>
                    </Stack.Item>

                    {/* Lewd Slot Management */}
                    {verb_mode_data?.lewd_slots &&
                      verb_mode_data.lewd_slots.length > 0 && (
                        <Stack.Item>
                          <Section title="LEWD SLOT MANAGEMENT">
                            <Stack fill>
                              {verb_mode_data.lewd_slots.map((slot) => (
                                <Stack.Item key={slot.slot}>
                                  <Button
                                    onClick={() =>
                                      act('remove_lewd_item', {
                                        item_slot: slot.slot,
                                      })
                                    }
                                    color="pink"
                                    tooltip={slot.name}
                                  >
                                    <Box
                                      style={{
                                        width: '32px',
                                        height: '32px',
                                        margin: '0.5em 0',
                                      }}
                                    >
                                      {slot.img ? (
                                        <img
                                          src={`data:image/png;base64,${slot.img}`}
                                          style={{
                                            width: '100%',
                                            height: '100%',
                                          }}
                                        />
                                      ) : (
                                        <Icon
                                          name="eye-slash"
                                          size={2}
                                          ml={0}
                                          mt={0.75}
                                          style={{
                                            textAlign: 'center',
                                          }}
                                        />
                                      )}
                                    </Box>
                                  </Button>
                                </Stack.Item>
                              ))}
                            </Stack>
                          </Section>
                        </Stack.Item>
                      )}
                  </>
                </Stack>
              </Section>
            </Stack.Item>

            {/* Right Panel - Chat */}
            <Stack.Item grow>
              <Stack fill vertical>
                {
                  // Chat mode
                  <>
                    {/* Top section: Participant management */}
                    <Stack.Item>
                      <Section
                        title="Primary Panel"
                        buttons={
                          <Stack>
                            <Stack.Item>
                              <Button.Checkbox
                                checked={autocum_enabled}
                                onClick={() => act('toggle_autocum')}
                                tooltip="Enable automatic climax when arousal threshold is reached"
                              >
                                Autocum
                              </Button.Checkbox>
                            </Stack.Item>
                            <Stack.Item>
                              <Button
                                icon="heart"
                                color="pink"
                                onClick={() => act('trigger_climax')}
                                tooltip="Manually trigger climax"
                              >
                                Climax
                              </Button>
                            </Stack.Item>
                          </Stack>
                        }
                      >
                        <Stack fill>
                          {/* Participants list */}
                          <Stack.Item grow>
                            <Section
                              title={
                                <Stack>
                                  <Stack.Item grow>Participants</Stack.Item>
                                  <Stack.Item>
                                    <Button
                                      icon="users"
                                      onClick={() => {
                                        // Open participant management modal or dropdown
                                        // For now, we'll just show available players in a modal
                                        setShowParticipantManagement(true);
                                      }}
                                    >
                                      Manage
                                    </Button>
                                  </Stack.Item>
                                </Stack>
                              }
                              scrollable
                              maxHeight="150px"
                            >
                              {participants.length === 0 ? (
                                <Box
                                  style={{
                                    color: currentTheme.labelText || undefined,
                                  }}
                                >
                                  No participants added
                                </Box>
                              ) : (
                                <Stack fill vertical>
                                  {participants.map((participant) => (
                                    <Stack.Item key={participant.ref}>
                                      <Box
                                        style={{
                                          padding: '4px',
                                          'margin-bottom': '2px',
                                        }}
                                      >
                                        <Stack>
                                          <Stack.Item grow>
                                            <Stack vertical>
                                              <Stack.Item>
                                                <Box bold>
                                                  {participant.name}
                                                </Box>
                                              </Stack.Item>
                                              {participant.is_typing && (
                                                <Stack.Item>
                                                  <Box color="label" italic>
                                                    <Box as="span" bold>
                                                      {participant.name}
                                                    </Box>
                                                    {' is typing '}
                                                    <TypingDots />
                                                  </Box>
                                                </Stack.Item>
                                              )}
                                            </Stack>
                                          </Stack.Item>
                                          <Stack.Item>
                                            <Button
                                              icon="times"
                                              color="red"
                                              onClick={() =>
                                                act('remove_participant', {
                                                  ref: participant.ref,
                                                })
                                              }
                                            >
                                              Remove
                                            </Button>
                                          </Stack.Item>
                                        </Stack>
                                      </Box>
                                    </Stack.Item>
                                  ))}
                                </Stack>
                              )}
                            </Section>
                          </Stack.Item>

                          {/* Pleasure, Arousal, Pain bars */}
                          <Stack.Item grow>
                            <Section>
                              <Stack vertical>
                                {/* Pleasure bar */}
                                <Stack.Item>
                                  <Box
                                    style={{
                                      border: '2px solid #b19cd9',
                                      padding: '4px 8px',
                                      'background-color':
                                        currentTheme.statusBarBackground ||
                                        '#1e1e1e',
                                      display: 'flex',
                                      'align-items': 'center',
                                      'justify-content': 'space-between',
                                      'min-height': '32px',
                                      position: 'relative',
                                      overflow: 'hidden',
                                    }}
                                  >
                                    <Box
                                      style={{
                                        position: 'absolute',
                                        left: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: `${Math.min(100, ((selected_participant?.pleasure || 0) / 100) * 100)}%`,
                                        'background-color':
                                          'rgba(177, 156, 217, 0.3)',
                                        'z-index': 0,
                                      }}
                                    />
                                    <Stack
                                      style={{
                                        position: 'relative',
                                        'z-index': 1,
                                        width: '100%',
                                      }}
                                    >
                                      <Stack.Item grow />
                                      <Stack.Item>
                                        <Stack>
                                          <Stack.Item>
                                            <Box
                                              style={{
                                                'font-size': '14px',
                                                color:
                                                  currentTheme.statusBarText ||
                                                  '#fff',
                                                'margin-right': '8px',
                                              }}
                                            >
                                              <Icon name="heart" />
                                            </Box>
                                          </Stack.Item>
                                          <Stack.Item>
                                            <Box
                                              style={{
                                                'font-size': '14px',
                                                color:
                                                  currentTheme.statusBarText ||
                                                  '#fff',
                                              }}
                                            >
                                              Pleasure
                                            </Box>
                                          </Stack.Item>
                                        </Stack>
                                      </Stack.Item>
                                    </Stack>
                                  </Box>
                                </Stack.Item>
                                {/* Arousal bar */}
                                <Stack.Item>
                                  <Box
                                    style={{
                                      border: '2px solid #d19cd9',
                                      padding: '4px 8px',
                                      'background-color':
                                        currentTheme.statusBarBackground ||
                                        '#1e1e1e',
                                      display: 'flex',
                                      'align-items': 'center',
                                      'justify-content': 'space-between',
                                      'min-height': '32px',
                                      position: 'relative',
                                      overflow: 'hidden',
                                    }}
                                  >
                                    <Box
                                      style={{
                                        position: 'absolute',
                                        left: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: `${Math.min(100, ((selected_participant?.arousal || 0) / 100) * 100)}%`,
                                        'background-color':
                                          'rgba(209, 156, 217, 0.3)',
                                        'z-index': 0,
                                      }}
                                    />
                                    <Stack
                                      style={{
                                        position: 'relative',
                                        'z-index': 1,
                                        width: '100%',
                                      }}
                                    >
                                      <Stack.Item grow />
                                      <Stack.Item>
                                        <Stack>
                                          <Stack.Item>
                                            <Box
                                              style={{
                                                'font-size': '14px',
                                                color:
                                                  currentTheme.statusBarText ||
                                                  '#fff',
                                                'margin-right': '8px',
                                              }}
                                            >
                                              <Icon name="tint" />
                                            </Box>
                                          </Stack.Item>
                                          <Stack.Item>
                                            <Box
                                              style={{
                                                'font-size': '14px',
                                                color:
                                                  currentTheme.statusBarText ||
                                                  '#fff',
                                              }}
                                            >
                                              Arousal
                                            </Box>
                                          </Stack.Item>
                                        </Stack>
                                      </Stack.Item>
                                    </Stack>
                                  </Box>
                                </Stack.Item>
                                {/* Pain bar */}
                                <Stack.Item>
                                  <Box
                                    style={{
                                      border: '2px solid #ff4444',
                                      padding: '4px 8px',
                                      'background-color':
                                        currentTheme.statusBarBackground ||
                                        '#1e1e1e',
                                      display: 'flex',
                                      'align-items': 'center',
                                      'justify-content': 'space-between',
                                      'min-height': '32px',
                                      position: 'relative',
                                      overflow: 'hidden',
                                    }}
                                  >
                                    <Box
                                      style={{
                                        position: 'absolute',
                                        left: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: `${Math.min(100, ((selected_participant?.pain || 0) / 100) * 100)}%`,
                                        'background-color':
                                          'rgba(255, 68, 68, 0.3)',
                                        'z-index': 0,
                                      }}
                                    />
                                    <Stack
                                      style={{
                                        position: 'relative',
                                        'z-index': 1,
                                        width: '100%',
                                      }}
                                    >
                                      <Stack.Item grow />
                                      <Stack.Item>
                                        <Stack>
                                          <Stack.Item>
                                            <Box
                                              style={{
                                                'font-size': '14px',
                                                color:
                                                  currentTheme.statusBarText ||
                                                  '#fff',
                                                'margin-right': '8px',
                                              }}
                                            >
                                              <Icon name="bolt" />
                                            </Box>
                                          </Stack.Item>
                                          <Stack.Item>
                                            <Box
                                              style={{
                                                'font-size': '14px',
                                                color:
                                                  currentTheme.statusBarText ||
                                                  '#fff',
                                              }}
                                            >
                                              Pain
                                            </Box>
                                          </Stack.Item>
                                        </Stack>
                                      </Stack.Item>
                                    </Stack>
                                  </Box>
                                </Stack.Item>
                              </Stack>
                            </Section>
                          </Stack.Item>
                        </Stack>
                      </Section>
                    </Stack.Item>

                    {/* Chat area */}
                    <Stack.Item grow>
                      <Section title="Log" fill scrollable>
                        {messages.length === 0 ? (
                          <Box
                            textAlign="center"
                            mt={2}
                            style={{
                              color: currentTheme.labelText || undefined,
                            }}
                          >
                            No messages yet. Send an emote to start!
                          </Box>
                        ) : (
                          <Stack fill vertical>
                            {messages.map((msg, index) => (
                              <Stack.Item key={index}>
                                <Box
                                  style={{
                                    padding: '8px',
                                    'margin-bottom': '4px',
                                    'border-left': '3px solid',
                                    'border-color':
                                      msg.mode === 'say'
                                        ? '#88f'
                                        : msg.mode === 'whisper'
                                          ? '#8ff'
                                          : msg.mode === 'public'
                                            ? '#88e'
                                            : msg.mode === 'subtle'
                                              ? '#8e8'
                                              : '#e88',
                                  }}
                                >
                                  <Stack>
                                    {msg.headshot && (
                                      <Stack.Item>
                                        <Stack vertical>
                                          <Stack.Item>
                                            <Box
                                              as="img"
                                              src={msg.headshot}
                                              onClick={() => {
                                                if (msg.ref) {
                                                  act('open_examine', {
                                                    ref: msg.ref,
                                                  });
                                                }
                                              }}
                                              style={{
                                                width: '64px',
                                                height: '64px',
                                                'object-fit': 'cover',
                                                'border-radius': '4px',
                                                'margin-right': '8px',
                                                cursor: msg.ref
                                                  ? 'pointer'
                                                  : 'default',
                                                opacity: msg.ref ? 1 : 0.8,
                                                transition: 'opacity 0.2s',
                                              }}
                                              onMouseEnter={(e) => {
                                                if (msg.ref) {
                                                  e.currentTarget.style.opacity =
                                                    '0.7';
                                                }
                                              }}
                                              onMouseLeave={(e) => {
                                                if (msg.ref) {
                                                  e.currentTarget.style.opacity =
                                                    '1';
                                                }
                                              }}
                                            />
                                          </Stack.Item>
                                        </Stack>
                                      </Stack.Item>
                                    )}
                                    <Stack.Item grow>
                                      {msg.mode === 'say' ? (
                                        <Box>
                                          <Box as="span" bold>
                                            {msg.name}
                                          </Box>
                                          <Box as="span">
                                            {' '}
                                            says, "
                                            <span
                                              dangerouslySetInnerHTML={{
                                                __html: decodeHtmlEntities(
                                                  msg.message,
                                                ).replace(/\n/g, '<br />'),
                                              }}
                                            />
                                            "
                                          </Box>
                                        </Box>
                                      ) : msg.mode === 'whisper' ? (
                                        <Box>
                                          <Box as="span" bold>
                                            {msg.name}
                                          </Box>
                                          <Box as="span">
                                            {' '}
                                            whispers, "
                                            <span
                                              dangerouslySetInnerHTML={{
                                                __html: decodeHtmlEntities(
                                                  msg.message,
                                                ).replace(/\n/g, '<br />'),
                                              }}
                                            />
                                            "
                                          </Box>
                                        </Box>
                                      ) : msg.mode === 'subtle' ||
                                        msg.mode === 'subtle_antighost' ? (
                                        <Box>
                                          <Box as="span" bold>
                                            {msg.name}
                                          </Box>
                                          <Box
                                            as="span"
                                            dangerouslySetInnerHTML={{
                                              __html:
                                                ' ' +
                                                decodeHtmlEntities(
                                                  msg.message,
                                                ).replace(/\n/g, '<br />'),
                                            }}
                                          />
                                        </Box>
                                      ) : (
                                        <Box
                                          dangerouslySetInnerHTML={{
                                            __html:
                                              '<span style="font-weight: bold;">' +
                                              decodeHtmlEntities(msg.name) +
                                              ' </span>' +
                                              decodeHtmlEntities(
                                                msg.message,
                                              ).replace(/\n/g, '<br />'),
                                          }}
                                        />
                                      )}
                                      <Stack>
                                        <Stack.Item grow>
                                          <Box
                                            color="label"
                                            fontSize="0.8em"
                                            mt={0.5}
                                          >
                                            {emote_modes[msg.mode] || msg.mode}
                                          </Box>
                                        </Stack.Item>
                                        {msg.timestamp && (
                                          <Stack.Item>
                                            <Box
                                              color="label"
                                              fontSize="0.8em"
                                              mt={0.5}
                                            >
                                              {msg.timestamp}
                                            </Box>
                                          </Stack.Item>
                                        )}
                                      </Stack>
                                    </Stack.Item>
                                  </Stack>
                                </Box>
                              </Stack.Item>
                            ))}
                            {/* Typing indicators */}
                            {participants
                              .filter((p) => p.is_typing)
                              .map((participant) => (
                                <Stack.Item key={`typing-${participant.ref}`}>
                                  <Box
                                    color="label"
                                    italic
                                    style={{
                                      padding: '4px 8px',
                                      'margin-top': '4px',
                                    }}
                                  >
                                    <Box as="span" bold>
                                      {participant.name}
                                    </Box>
                                    {' is typing '}
                                    <TypingDots />
                                  </Box>
                                </Stack.Item>
                              ))}
                            <div ref={messagesEndRef} />
                          </Stack>
                        )}
                      </Section>
                    </Stack.Item>

                    {/* Message input */}
                    <Stack.Item>
                      <Section>
                        <Stack fill vertical>
                          <Stack.Item>
                            <Stack fill>
                              <Stack.Item grow>
                                <Box
                                  as="textarea"
                                  ref={inputRef}
                                  fluid
                                  placeholder="Type your message here..."
                                  value={messageInput || ''}
                                  onInput={(e) => {
                                    const value = e.target.value || '';
                                    if (value.length <= MAX_MESSAGE_LENGTH) {
                                      setMessageInput(value);
                                    } else {
                                      setMessageInput(
                                        value.substring(0, MAX_MESSAGE_LENGTH),
                                      );
                                    }
                                  }}
                                  onKeyDown={(e) => {
                                    if (e.key === 'Enter' && !e.shiftKey) {
                                      e.preventDefault();
                                      handleSendMessage();
                                    }
                                  }}
                                  style={{
                                    'min-height': '48px',
                                    'max-height': '200px',
                                    resize: 'vertical',
                                    'font-family': 'inherit',
                                    'font-size': 'inherit',
                                    padding: '4px 8px',
                                    border: `1px solid ${currentTheme.inputBorder || '#555'}`,
                                    'background-color':
                                      currentTheme.inputBackground || '#1e1e1e',
                                    color: currentTheme.inputText || '#fff',
                                    'border-radius': '2px',
                                    'line-height': '1.4',
                                    'overflow-y': 'auto',
                                    width: '100%',
                                  }}
                                />
                              </Stack.Item>
                            </Stack>
                          </Stack.Item>
                          <Stack.Item>
                            <Stack fill>
                              <Stack.Item>
                                <Box
                                  fontSize="0.8em"
                                  style={{
                                    color: currentTheme.labelText || undefined,
                                  }}
                                >
                                  {messageInput ? messageInput.length : 0} /{' '}
                                  {MAX_MESSAGE_LENGTH} characters
                                </Box>
                              </Stack.Item>
                              <Stack.Item grow />
                              <Stack.Item>
                                <Dropdown
                                  width="150px"
                                  selected={emote_mode}
                                  options={Object.entries(emote_modes).map(
                                    ([key, label]) => ({
                                      value: key,
                                      displayText: label,
                                    }),
                                  )}
                                  onSelected={(value) =>
                                    act('set_emote_mode', { mode: value })
                                  }
                                />
                              </Stack.Item>
                              <Stack.Item>
                                <Button
                                  icon="paper-plane"
                                  onClick={handleSendMessage}
                                  disabled={
                                    !messageInput || !messageInput.trim()
                                  }
                                  color="blue"
                                >
                                  Send
                                </Button>
                              </Stack.Item>
                            </Stack>
                          </Stack.Item>
                        </Stack>
                      </Section>
                    </Stack.Item>
                  </>
                }
              </Stack>
            </Stack.Item>
          </Stack>
        </Window.Content>
      </Window>
      {showParticipantManagement && (
        <Modal width="500px" style={{ zIndex: 1000 }}>
          <Section
            title="Participant Management"
            buttons={
              <Button
                icon="times"
                onClick={() => setShowParticipantManagement(false)}
              >
                Close
              </Button>
            }
          >
            <Section
              title="Available Players (5x5 range)"
              scrollable
              maxHeight="300px"
            >
              {available_players.length === 0 ? (
                <Box color="label">No players in range</Box>
              ) : (
                <Table>
                  {available_players.map((player) => (
                    <Table.Row key={player.ref}>
                      <Table.Cell>
                        {player.headshot && (
                          <img
                            src={player.headshot}
                            style={{
                              width: '64px',
                              height: '64px',
                              'object-fit': 'cover',
                              'border-radius': '4px',
                              'margin-right': '8px',
                              display: 'inline-block',
                              'vertical-align': 'middle',
                            }}
                          />
                        )}
                        {player.name}
                      </Table.Cell>
                      <Table.Cell textAlign="right">
                        <Button
                          icon="plus"
                          color="green"
                          onClick={() => {
                            act('add_participant', { ref: player.ref });
                          }}
                        >
                          Add
                        </Button>
                      </Table.Cell>
                    </Table.Row>
                  ))}
                </Table>
              )}
            </Section>
          </Section>
        </Modal>
      )}
      {showManageSelf && (
        <Modal width="600px" style={{ zIndex: 1001, position: 'relative' }}>
          <Section
            title="Manage Self"
            buttons={
              <Button icon="times" onClick={() => setShowManageSelf(false)}>
                Close
              </Button>
            }
          >
            <Stack fill vertical>
              <Stack.Item>
                <Section title="Character Prefs">
                  <Stack fill vertical>
                    {/* ERP Preference */}
                    <Stack.Item>
                      <Stack>
                        <Stack.Item>
                          <Box fontSize="0.9em" style={{ minWidth: '120px' }}>
                            ERP:
                          </Box>
                        </Stack.Item>
                        <Stack.Item grow>
                          <Stack wrap>
                            {[
                              'Top - Dom',
                              'Top - Switch',
                              'Top - Sub',
                              'Verse-Top - Dom',
                              'Verse-Top - Switch',
                              'Verse-Top - Sub',
                              'Verse - Dom',
                              'Verse - Switch',
                              'Verse - Sub',
                              'Verse-Bottom - Dom',
                              'Verse-Bottom - Switch',
                              'Verse-Bottom - Sub',
                              'Bottom - Dom',
                              'Bottom - Switch',
                              'Bottom - Sub',
                              'Check OOC Notes',
                              'Ask (L)OOC',
                              'No',
                              'Yes',
                            ].map((option) => (
                              <Stack.Item key={option} mr={0.3} mb={0.3}>
                                <Button
                                  selected={
                                    self_preferences?.erp_status === option
                                  }
                                  onClick={() => {
                                    act('set_self_preference', {
                                      pref_type: 'erp_status',
                                      pref_value: option,
                                    });
                                  }}
                                >
                                  {option}
                                </Button>
                              </Stack.Item>
                            ))}
                          </Stack>
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>

                    {/* Noncon Preference */}
                    <Stack.Item>
                      <Stack>
                        <Stack.Item>
                          <Box fontSize="0.9em" style={{ minWidth: '120px' }}>
                            Noncon:
                          </Box>
                        </Stack.Item>
                        <Stack.Item grow>
                          <Stack wrap>
                            {[
                              'Yes - Switch',
                              'Yes - Dom',
                              'Yes - Sub',
                              'Yes',
                              'Ask (L)OOC',
                              'Check OOC Notes',
                              'No',
                            ].map((option) => (
                              <Stack.Item key={option} mr={0.3} mb={0.3}>
                                <Button
                                  selected={
                                    self_preferences?.erp_status_nc === option
                                  }
                                  onClick={() => {
                                    act('set_self_preference', {
                                      pref_type: 'erp_status_nc',
                                      pref_value: option,
                                    });
                                  }}
                                >
                                  {option}
                                </Button>
                              </Stack.Item>
                            ))}
                          </Stack>
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>

                    {/* Vore Preference */}
                    <Stack.Item>
                      <Stack>
                        <Stack.Item>
                          <Box fontSize="0.9em" style={{ minWidth: '120px' }}>
                            Vore:
                          </Box>
                        </Stack.Item>
                        <Stack.Item grow>
                          <Stack wrap>
                            {[
                              'Yes - Switch',
                              'Yes - Prey',
                              'Yes - Pred',
                              'Check OOC Notes',
                              'Ask (L)OOC',
                              'No',
                              'Yes',
                            ].map((option) => (
                              <Stack.Item key={option} mr={0.3} mb={0.3}>
                                <Button
                                  selected={
                                    self_preferences?.erp_status_v === option
                                  }
                                  onClick={() => {
                                    act('set_self_preference', {
                                      pref_type: 'erp_status_v',
                                      pref_value: option,
                                    });
                                  }}
                                >
                                  {option}
                                </Button>
                              </Stack.Item>
                            ))}
                          </Stack>
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>

                    {/* Hypnosis Preference */}
                    <Stack.Item>
                      <Stack>
                        <Stack.Item>
                          <Box fontSize="0.9em" style={{ minWidth: '120px' }}>
                            Hypnosis:
                          </Box>
                        </Stack.Item>
                        <Stack.Item grow>
                          <Stack wrap>
                            {[
                              'Yes - Switch',
                              'Yes - Dom',
                              'Yes - Sub',
                              'Check OOC',
                              'Ask',
                              'No',
                              'Yes',
                            ].map((option) => (
                              <Stack.Item key={option} mr={0.3} mb={0.3}>
                                <Button
                                  selected={
                                    self_preferences?.erp_status_hypno ===
                                    option
                                  }
                                  onClick={() => {
                                    act('set_self_preference', {
                                      pref_type: 'erp_status_hypno',
                                      pref_value: option,
                                    });
                                  }}
                                >
                                  {option}
                                </Button>
                              </Stack.Item>
                            ))}
                          </Stack>
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>

                    {/* Depraved Preference */}
                    <Stack.Item>
                      <Stack>
                        <Stack.Item>
                          <Box fontSize="0.9em" style={{ minWidth: '120px' }}>
                            Depraved:
                          </Box>
                        </Stack.Item>
                        <Stack.Item grow>
                          <Stack wrap>
                            {['Yes', 'Ask (L)OOC', 'Check OOC Notes', 'No'].map(
                              (option) => (
                                <Stack.Item key={option} mr={0.3} mb={0.3}>
                                  <Button
                                    selected={
                                      self_preferences?.erp_status_depraved ===
                                      option
                                    }
                                    onClick={() => {
                                      act('set_self_preference', {
                                        pref_type: 'erp_status_depraved',
                                        pref_value: option,
                                      });
                                    }}
                                  >
                                    {option}
                                  </Button>
                                </Stack.Item>
                              ),
                            )}
                          </Stack>
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>

                    {/* Violent Preference */}
                    <Stack.Item>
                      <Stack>
                        <Stack.Item>
                          <Box fontSize="0.9em" style={{ minWidth: '120px' }}>
                            Violent:
                          </Box>
                        </Stack.Item>
                        <Stack.Item grow>
                          <Stack wrap>
                            {['Yes', 'Ask (L)OOC', 'Check OOC Notes', 'No'].map(
                              (option) => (
                                <Stack.Item key={option} mr={0.3} mb={0.3}>
                                  <Button
                                    selected={
                                      self_preferences?.erp_status_violent ===
                                      option
                                    }
                                    onClick={() => {
                                      act('set_self_preference', {
                                        pref_type: 'erp_status_violent',
                                        pref_value: option,
                                      });
                                    }}
                                  >
                                    {option}
                                  </Button>
                                </Stack.Item>
                              ),
                            )}
                          </Stack>
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>

                    {/* ERP Mechanics */}
                    <Stack.Item>
                      <Stack>
                        <Stack.Item>
                          <Box fontSize="0.9em" style={{ minWidth: '120px' }}>
                            Mechanics:
                          </Box>
                        </Stack.Item>
                        <Stack.Item grow>
                          <Stack wrap>
                            {[
                              'Roleplay only',
                              'Mechanical only',
                              'Mechanical and Roleplay',
                              'None',
                            ].map((option) => (
                              <Stack.Item key={option} mr={0.3} mb={0.3}>
                                <Button
                                  selected={
                                    self_preferences?.erp_status_mechanics ===
                                    option
                                  }
                                  onClick={() => {
                                    act('set_self_preference', {
                                      pref_type: 'erp_status_mechanics',
                                      pref_value: option,
                                    });
                                  }}
                                >
                                  {option}
                                </Button>
                              </Stack.Item>
                            ))}
                          </Stack>
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>
                  </Stack>
                </Section>
              </Stack.Item>

              {/* Genital Visibility */}
              {self_preferences?.genitals &&
                self_preferences.genitals.length > 0 && (
                  <Stack.Item mt={1}>
                    <Section title="Genital Visibility">
                      <Stack fill vertical>
                        {self_preferences.genitals.map((genital) => (
                          <Stack.Item key={genital.slot}>
                            <Stack>
                              <Stack.Item grow>
                                <Box>{genital.name}:</Box>
                              </Stack.Item>
                              <Stack.Item>
                                <Button
                                  selected={genital.visibility === 1}
                                  onClick={() =>
                                    act('set_genital_visibility', {
                                      organ_slot: genital.slot,
                                      visibility: 1,
                                    })
                                  }
                                >
                                  Never Show
                                </Button>
                              </Stack.Item>
                              <Stack.Item>
                                <Button
                                  selected={genital.visibility === 2}
                                  onClick={() =>
                                    act('set_genital_visibility', {
                                      organ_slot: genital.slot,
                                      visibility: 2,
                                    })
                                  }
                                >
                                  Hidden by Clothes
                                </Button>
                              </Stack.Item>
                              <Stack.Item>
                                <Button
                                  selected={genital.visibility === 3}
                                  onClick={() =>
                                    act('set_genital_visibility', {
                                      organ_slot: genital.slot,
                                      visibility: 3,
                                    })
                                  }
                                >
                                  Always Show
                                </Button>
                              </Stack.Item>
                            </Stack>
                          </Stack.Item>
                        ))}
                      </Stack>
                    </Section>
                  </Stack.Item>
                )}

              {/* Underwear Visibility Management */}
              <Stack.Item mt={1}>
                <Section title="Underwear Visibility">
                  <Stack fill vertical>
                    <Stack.Item>
                      <Button.Checkbox
                        fluid
                        checked={self_preferences?.hide_underwear || false}
                        onClick={() => {
                          act('toggle_underwear_visibility', {
                            underwear_type: 'underwear',
                          });
                        }}
                      >
                        Hide Underwear
                      </Button.Checkbox>
                    </Stack.Item>
                    <Stack.Item>
                      <Button.Checkbox
                        fluid
                        checked={self_preferences?.hide_bra || false}
                        onClick={() => {
                          act('toggle_underwear_visibility', {
                            underwear_type: 'bra',
                          });
                        }}
                      >
                        Hide Bra
                      </Button.Checkbox>
                    </Stack.Item>
                    <Stack.Item>
                      <Button.Checkbox
                        fluid
                        checked={self_preferences?.hide_undershirt || false}
                        onClick={() => {
                          act('toggle_underwear_visibility', {
                            underwear_type: 'undershirt',
                          });
                        }}
                      >
                        Hide Undershirt
                      </Button.Checkbox>
                    </Stack.Item>
                    <Stack.Item>
                      <Button.Checkbox
                        fluid
                        checked={self_preferences?.hide_socks || false}
                        onClick={() => {
                          act('toggle_underwear_visibility', {
                            underwear_type: 'socks',
                          });
                        }}
                      >
                        Hide Socks
                      </Button.Checkbox>
                    </Stack.Item>
                  </Stack>
                </Section>
              </Stack.Item>
            </Stack>
          </Section>
        </Modal>
      )}
    </>
  );
};
