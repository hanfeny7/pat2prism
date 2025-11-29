//@Model: Collision avoidance protocol 
//@Tag: Protocol
/*@Description:
  We assume that a number of stations are connected on an Ethernet-like medium. 
  On top of this basic protocol we want to design a protocol without collisions. 
  In the protocol's operation, the master station begins by sending out queries to the slave stations, asking if they have any data to transmit. 
  This is done in a round-robin manner, ensuring that each slave station has the opportunity to respond without overlapping transmission attempts. 
  The slave stations listen for these requests and indicate their status by waiting for the master's turn. 
  If a slave station has data to send, it will respond accordingly, allowing the channel to be utilized efficiently and without conflict. 
  The provided model is rather simple, because it does not take the time aspects into consideration. 
*/

#define SIZE 0;
#define N 2; // number of slave stations

channel to_medium				SIZE;
channel from_medium[N+1]		SIZE;
channel in[N+1]					SIZE;
channel out[N+1]				SIZE;

var wait[N+1] = [1(N+1)];
hvar collision_occur = false;	

//temporary variables storing the channel read
var curr[N+1];
var t_i;
var t_m;

//Data Fomate : [data][receiver][sender], data = {0,1}, receiver,sender = {0..N}, 0 indicates master
//Example	  
//	020:	Enquery from Master to 2nd Slave
//	132:	Send data from 2nd o 3rd slave
				
Medium() = to_medium?m{ curr[0] = m;} -> Medium()										/* Lost incoming message*/
		[] to_medium?m{ wait[0] = 0; curr[0] = m;} -> 
			(
				to_medium?m2{ curr[0] = m2; collision_occur = true;} -> Stop
				[] got2cast{ t_i = 0;} -> BroadCast()
			);
		
//BroadCast using round-robin fashion

BroadCast() = []x:{0..N}@([x != curr[0]%10 && x == t_i]from_medium[x]!curr[0]{t_i++;} -> BroadCast())
			[][t_i == curr[0]%10]broad.1{ t_i++; } -> BroadCast()
			[][t_i != curr[0]%10 && t_i <= N]broad.2{ t_i++; } -> BroadCast()
			[][0 != curr[0]%10 && 0 == t_i]from_medium[0]!curr[0]{ t_i++; } -> BroadCast()
			[][t_i == N + 1]broad2wait{ wait[0] = 1;} -> Medium();
				
Slave(i) = from_medium[i]?m{ wait[i] = 0; curr[i] = m; } -> 
		(
			[(curr[i] % (10 * 10)) / 10 != i]got2wait.i.1{ wait[i] = 1; } -> Slave(i)								/* The receiver is not 1*/
		[]	[(curr[i] % (10 * 10)) / 10 == i && (curr[i] / (10 * 10)) != 0] out[i]!(curr[i]/(10*10)){ wait[i] = 1; } -> Slave(i)		/*The receiver is 1 and it is a data transmission*/
		[] 	[(curr[i] % (10 * 10)) / 10 == i && (curr[i] / (10 * 10)) == 0] in[i]?m_in{curr[i] = m_in;} -> 
			(							/*The receiver is 1 and it is an enquery*/
				[m_in == 0] enq2wait.i.1{ wait[i] = 1; } -> Slave(i)	/*User1 has not data to send*/
			[]	[m_in != 0] to_medium!(i + (m_in%10) * 10 + ((m_in%100)/10)*100){ wait[i] = 1; } -> Slave(i) 
			)
		);
var u_m[N];
User(i) = in[i]!0 -> User(i)						/*Not interesting*/
		[]in[i]!(i%N+1 + (i%N+1) * 10 + (0) * 100) -> User(i)
		[]out[i]?m{u_m[i-1] = m;} -> ([i == m] got2wait.i -> User(i) [] [i != m] wrong_data.i -> Stop);

var next = 1;
Master() = to_medium!((0)+(next)*10+(0*10*10)) -> MasterWait();
MasterWait() = [&&x:{0..N}@(wait[x] == 1)] wait2send{ next = next % N + 1;} -> Master() 
				[] from_medium[0]?m{ t_m = m;} -> MasterWait();

Collision() = (|||x:{1..N}@(Slave(x) ||| User(x))) ||| Medium() ||| Master();

/*@Properties:
  1. A collision can occur
  2. The protocol is deadlock-free
*/
#define goal collision_occur == true;
#assert Collision() reaches goal;

#assert Collision() deadlockfree;
