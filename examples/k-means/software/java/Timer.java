package nl.tudelft.ewi.ce.abs.kmeans;

public class Timer {
	long startTime;
	long stopTime;
	
	public void start() {
		startTime = System.nanoTime();
	}
	
	public void stop() {
		stopTime = System.nanoTime();
	}
	
	public double seconds() {
		return (stopTime - startTime) / 1000000000.0;
	}
}
