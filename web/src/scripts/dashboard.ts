import { Chart, LineController, LineElement, PointElement, LinearScale, CategoryScale, Filler, Tooltip, Legend } from 'chart.js';

Chart.register(LineController, LineElement, PointElement, LinearScale, CategoryScale, Filler, Tooltip, Legend);

const HISTORY_POINTS = 60;

const charts: Record<string, Chart> = {};
const dataBuffers: Record<string, number[]> = {
	voltage: [],
	current: [],
	power: [],
	frequency: [],
};

const labels = Array.from({ length: HISTORY_POINTS }, (_, i) => i.toString());

const chartConfig = {
	voltage: { color: 'rgb(37, 99, 235)', label: 'Voltage' },
	current: { color: 'rgb(249, 115, 22)', label: 'Current' },
	power: { color: 'rgb(34, 197, 94)', label: 'Power' },
	frequency: { color: 'rgb(147, 51, 234)', label: 'Frequency' },
};

const defaultOptions = {
	responsive: true,
	maintainAspectRatio: false,
	animation: { duration: 0 },
	plugins: {
		legend: { display: false },
		tooltip: { mode: 'index' as const, intersect: false },
	},
	scales: {
		x: {
			display: true,
			grid: { color: 'rgb(238, 238, 238)' },
			ticks: { display: false },
		},
		y: {
			display: true,
			grid: { color: 'rgb(238, 238, 238)' },
		},
	},
	elements: {
		point: { radius: 0 },
		line: { tension: 0.3 },
	},
};

function createChart(id: string, metricKey: string) {
	const { color, label } = chartConfig[metricKey as keyof typeof chartConfig];
	const ctx = document.getElementById(id)!.getContext('2d')!;
	charts[metricKey] = new Chart(ctx, {
		type: 'line',
		data: {
			labels: labels,
			datasets: [{
				label,
				data: dataBuffers[metricKey],
				borderColor: color,
				backgroundColor: color.replace('rgb', 'rgba').replace(')', ', 0.1)'),
				fill: true,
				borderWidth: 2,
			}],
		},
		options: defaultOptions,
	});
}

createChart('chart-voltage', 'voltage');
createChart('chart-current', 'current');
createChart('chart-power', 'power');
createChart('chart-frequency', 'frequency');

const statusDot = document.getElementById('status-dot')!;
const statusText = document.getElementById('status-text')!;

function setStatus(state: string, text?: string) {
	statusDot.className = 'w-3 h-3 rounded-full';
	if (state === 'connected') {
		statusDot.classList.add('bg-green-400');
		statusText.textContent = 'Connected';
	} else if (state === 'connecting') {
		statusDot.classList.add('bg-yellow-400');
		statusText.textContent = text || 'Connecting...';
	} else {
		statusDot.classList.add('bg-red-400');
		statusText.textContent = text || 'Disconnected';
	}
}

function updateValue(id: string, value: number, decimals: number = 2) {
	const el = document.getElementById(id)!;
	el.textContent = typeof value === 'number' ? value.toFixed(decimals) : '--';
}

function pushData(metricKey: string, value: number) {
	dataBuffers[metricKey].push(value);
	if (dataBuffers[metricKey].length > HISTORY_POINTS) {
		dataBuffers[metricKey].shift();
	}
	charts[metricKey].update('none');
}

interface SensorData {
	current: number;
	voltage: number;
	power: number;
	frequency: number;
	power_usage: number;
}

let ws: WebSocket | null = null;
let reconnectDelay = 1000;
let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

function connectWs() {
	setStatus('connecting');
	const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
	const host = window.location.host;
	ws = new WebSocket(`${protocol}//${host}/ws`);

	ws.onopen = () => {
		setStatus('connected');
		reconnectDelay = 1000;
	};

	ws.onmessage = (event) => {
		try {
			const data: SensorData = JSON.parse(event.data);
			updateValue('voltage-value', data.voltage);
			updateValue('current-value', data.current);
			updateValue('power-value', data.power);
			updateValue('frequency-value', data.frequency);
			updateValue('energy-value', data.power_usage, 3);

			pushData('voltage', data.voltage);
			pushData('current', data.current);
			pushData('power', data.power);
			pushData('frequency', data.frequency);
		} catch (e) {
			console.error('Failed to parse WS message:', e);
		}
	};

	ws.onclose = () => {
		setStatus('disconnected');
		reconnectTimer = setTimeout(() => {
			reconnectDelay = Math.min(reconnectDelay * 2, 30000);
			connectWs();
		}, reconnectDelay);
	};

	ws.onerror = () => {
		ws?.close();
	};
}

connectWs();
