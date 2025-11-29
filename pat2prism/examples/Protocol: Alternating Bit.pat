//@Model: Alternating Bit Protocol
//@Tag: Protocol
/*@Description:
  Simple model of some basic protocol for communication over loosy channel (alternating bit protocol). 
 
  Messages are sent from sender A to receiver B. Assume that the channel 
  from A to B is initialized and that there are no messages in transit. 
  Each message from A to B contains a data part and a one-bit sequence number, 
  i.e., a value that is 0 or 1. B has two acknowledge characters that it can send to 
  A: ACK0 and ACK1. We assume that the channel may corrupt a message and that there 
  is a way in which A and B can decide whether or not they have received a correct message. 
  How and to which extent that is possible is the subject of coding theory. When A sends 
  a message, it sends it continuously, with the same sequence number, until it receives 
  an acknowledgment from B that contains the same sequence number. When that happens, 
  A complements (flips) the sequence number and starts transmitting the next message. 
  When B receives a message that is not corrupted and has sequence number 0, it starts 
  sending ACK0 and keeps doing so until it receives a valid message with number 1. 
  Then it starts sending ACK1, etc. This means that A may still receive ACK0 when 
  it is already transmitting messages with sequence number one. (And vice-versa.) 
  It treats such messages as negative-acknowledge characters (NAKs). 
  The simplest behaviour is to ignore them all and continue transmitting.
*/


channel K_in 0 ;
channel K_out 0 ;
channel L_in 0 ;
channel L_out 0 ;
channel send 0 ;
channel receive 0 ;

/*-----------------------------------------------------Channel K & Channel L-------------------------------------------------------------------------------------*/
 
var v_fake;
 
ChanK() = ReadyK(); 
ReadyK() = K_in?v{v_fake = v} -> ( ReadyK() [] K_out!v -> ReadyK());

var u_fake;

ChanL() = ReadyL(); 
ReadyL() = L_in?u{u_fake = u} -> ( ReadyL() [] L_out!u -> ReadyL());


/*-----------------------------------------------------Producer & Consumer-------------------------------------------------------------------------------------*/

hvar pready_flag = 1;
hvar produce0_flag = 0;


Producer() = pready{ pready_flag = 1; produce0_flag = 0 } -> Produce0() [] 
			 pready{ pready_flag = 1; produce0_flag = 0 } -> Produce1();
Produce0() = send!0{ produce0_flag = 1; pready_flag = 0 } -> Producer();
Produce1() = send!1{ pready_flag = 0 } -> Producer();



hvar consume0_flag = 0;
hvar consume1_flag = 0;
hvar cready_flag = 1;

var valuec_fake;

Consumer() = ReadyC();
ReadyC() = cready{ cready_flag = 1;consume0_flag = 0; consume1_flag = 0} -> receive?value{valuec_fake = value} -> GotmsgC(value);
GotmsgC(value) = ([ value == 0 ]consume0{ consume0_flag = 1;cready_flag = 0} -> ReadyC() [] [ value == 1 ]consume1{ consume1_flag = 1;cready_flag = 0 } ->  ReadyC());


/*-----------------------------------------------------Sender & Receiver-------------------------------------------------------------------------------------*/

var sab = 0;
var rab = 1;

var values_fake;

Sender1() = ReadyS1();
ReadyS1() = send?value{values_fake = value} -> Sending1(value);
Sending1(value) = K_in!value -> Sending1(value) []
				  L_out?ack -> Waitack1(ack);
Waitack1(ack) = [ ack != sab ]waitack1.0 -> Sending1(values_fake) []
				[ ack == sab ]waitack1.1{ sab = 1 - sab } -> ReadyS1();

var valuer_fake;

Receiver1() = Waitmsg1();
Waitmsg1() = L_in!rab -> Waitmsg1() []
			 K_out?value{valuer_fake = value} -> GotmsgR1(value);
GotmsgR1(value) = receive!value{ rab = 1 - rab } -> Waitmsg1();	


Protocol1() = ChanK() ||| ChanL() ||| Producer() ||| Consumer() ||| Sender1() ||| Receiver1();

/*@Properties:
  1. The protocol is deadlock-free
  2. Consumer can get message
  3. Consumer will eventually get message
  4. Consumer will get message infinitely often
  5. If the first produced value is 0, then the first consumed value is 0
*/

#assert Protocol1() deadlockfree;

#define consume_got (consume0_flag == 1 || consume1_flag == 1);
#assert Protocol1() reaches consume_got;

#assert Protocol1() |=<> consume_got;

#assert Protocol1() |=[]<> consume_got;

#define pready_pro (pready_flag == 1);
#define cready_pro (cready_flag == 1);
#define produce0_pro (produce0_flag == 1);
#define consume0_pro (consume0_flag == 1);
#assert Protocol1() |=  (pready_pro U produce0_pro) -> ((cready_pro U consume0_pro) || ([] cready_pro)) ;       
