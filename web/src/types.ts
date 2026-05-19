export interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  streaming?: boolean;
  thinking?: boolean;
}

export interface Conversation {
  id: string;
  title: string;
  messages: Message[];
}
