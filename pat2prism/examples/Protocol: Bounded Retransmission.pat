//@Model: Bounded Retransmission Protocol(without timing aspects)
//@Tag: Protocol
/*@Description:
  The Bounded Retransmission Protocol is a protocol used in one of the Philips' products. 
  It is based on the well-known alternating bit protocol. It allows only bounded number of retransmissions of each frame (piece of a file). 
 
  The protocol works as follows: Messages are sent from a sender to a receiver. 
  Each message is assigned a sequence number to maintain order and track retransmissions. 
  The receiver acknowledges each successfully received message using an ACK. 
  If a message is lost or corrupted during transmission, the sender retransmits the message 
  until either an ACK is received or a maximum retransmission limit is reached. 
 
  The process begins with the sender transmitting the first packet. It starts a timer 
  and waits for an acknowledgment from the receiver. If the receiver successfully 
  receives the packet, it sends an ACK with the corresponding sequence number back to the sender. 
  The sender, upon receiving the ACK, moves on to the next packet. 
 
  If the sender does not receive an ACK within the timeout period, it retransmits the 
  same packet. This process continues until the packet is acknowledged or the 
  retransmission count exceeds the maximum limit. If the limit is exceeded, 
  the sender abandons the transmission of that packet and signals a failure to the 
  higher-level application.
 
  This model does not include timing aspects. 
*/

#define SIZE 0;				/* size of the channel*/
#define REPEAT 3;			/* maximal number of retransmissions*/
#define MAX_FRAMES 5;		/* maximal number of frames*/

#define I_OK 	1;			/**/
#define I_NOK 	2;			/**/
#define I_DK 	3;			/**/
#define I_FST 	4;			/**/
#define I_INC 	5;			/**/


channel Sin SIZE;
channel Sout SIZE;
channel toK SIZE;			//F
channel fromK SIZE;			//G
channel toL SIZE;			//A
channel fromL SIZE;			//B
channel timeout SIZE;
channel Rout SIZE;
channel shake SIZE;
channel shakePC SIZE;

var prod_n;												/* How many chunks in a list*/
var sys_error = false;									/* Consumer gets a wrong number of frames?*/
var res_pro;
Producer() = []i:{1..MAX_FRAMES}@ready2send.i{ prod_n = i; } -> ProducerSend();		/* Send MAX_FRAMES frames*/
ProducerSend() = Sin!prod_n -> Sout?result{res_pro = result;} -> (
												[result == I_OK] shakePC!0 -> Producer()				/* success*/
												[]	
												[result == I_NOK || result == I_DK]check2send -> ProducerSend()		/* fail*/
											);

var c_m;
var c_n;
Consumer() = Rout?m{c_m = m; c_n++;} -> GetMessage();

GetMessage() = [c_m == I_FST || c_m == I_INC] get2ready.0 -> Consumer()
				[][c_m == I_NOK] get2ready.1{c_n = 0;} -> Consumer()
				[][c_m == I_OK] check -> (
										[c_n == prod_n]shakePC?0{c_n = 0;} -> Consumer()
										[] 
										[c_n != prod_n] st_error{sys_error = true;} -> Stop						/* Error*/
									);

var ab;			//ab: alternating bit
var s_n;		//n : number of chunks in the list 
var s_i;		//i : current chunk in the list 
var counter;	//counter : the retry number
// we get the data from Producer (due to abstraction we are interested only in length)
Sender() = Sin?n{s_n = n; s_i = 1;} -> SenderIdle();			//idle -> next_frame

SenderIdle() = frame2send{counter = 0;} -> StartSending();	//next_frame -> send			

/**
 *StartSending ()
 * toK : [I_FST][I_OK || I_NOK][AB]
 */
 
 //we send one frame to K -- no data, but we have to say whether it is first and/or last package
StartSending() = [s_i == 1 && s_i == s_n] toK!(4+2+ab) ->  WaitAck()
				[][s_i  > 1 && s_i == s_n] toK!(2+ab) ->  WaitAck()
				[][s_i == 1 && s_i  < s_n] toK!(4+ab) ->  WaitAck()
				[][s_i  > 1 && s_i  < s_n] toK!ab ->  WaitAck();
//now we wait for acknowledge
WaitAck() = (fromL?0{ ab = 1 - ab;} -> ([s_i < s_n] success2frame{ s_i++;} -> SenderIdle()	/* continue for the next chunk*/
											[]	[s_i ==s_n] Sout!I_OK -> shake!0 -> Sender()
										  )		/* Completed! Reset for next producer*/
			)
			[]	[counter == REPEAT] timeout?0 -> (	[s_i<s_n] Sout!I_NOK -> shake!0 -> Sender()	/* failure in the transmission*/
													[][s_i==s_n] Sout!I_DK -> shake!0 -> Sender())	/* Don't know about the transmission*/
			[]	[counter < REPEAT] timeout?0{ counter++;} -> StartSending();

var r_v;
var exp_ab;
//value & 4 == first, value & 2 == last, value & 1 == rab
Receiver() = fromK?value{ r_v = value;} -> safe2received{exp_ab = r_v & 1;} -> FrameReceived()
			[] shake?0 -> Receiver();


FrameReceived() =  [(r_v & 1) == exp_ab && (r_v & 2) == 2] Rout!I_OK -> toL!0{ exp_ab = 1 - exp_ab;} -> ReceiverIdle()			/* Last chunk*/
				[]	[(r_v & 1) == exp_ab && (r_v & 2) == 0 && (r_v & 4) == 0] Rout!I_INC -> toL!0{ exp_ab = 1 - exp_ab;} -> ReceiverIdle()	/* middle chunk*/
				[]	[(r_v & 1) == exp_ab && (r_v & 2) == 0 && (r_v & 4) == 4] Rout!I_FST -> toL!0{ exp_ab = 1 - exp_ab;} -> ReceiverIdle()	/* first chunk*/
				[]	[exp_ab != (r_v & 1)] toL!0 -> ReceiverIdle();
//Idle status of receiver
ReceiverIdle() = (fromK?value{r_v = value;} -> FrameReceived())	/* Not completed, continue receiving*/      /*!!!!IMPORTANT: change fromK?value to fromK?t_value to avoid cannot read datum from channel fromK */
				[][(r_v & 2) == 2] idle2ret -> shake?0 -> Receiver()		/* Last chunk is received*/
				[]Rout!I_NOK -> shake?0 -> Receiver();						// no guards?

var k_value;				
K() = toK?value{k_value = value;} -> (fromK!value -> K() [] timeout!0 -> K());
L() = toL?0 -> (fromL!0 -> L()  [] timeout!0 -> L() );


BRP() = Producer() ||| Consumer() ||| Sender() ||| Receiver() ||| K() ||| L ();

/*@Properties:
  1. The protocol is deadlock-free
  2. Consumer gets a wrong number of frames (an error)
  3. If the producer sends message, it will eventually get some acknowledgement from the Sender process.
  4. If the producer sends message, it will eventually get positive acknowledgement (=send ok) from the Sender process.
*/

#assert BRP() deadlockfree;

#define goal sys_error == true;
#assert BRP() reaches goal;										

#assert BRP() |= ([](Sin.1 -> <>(Sout.I_OK || Sout.I_NOK || Sout.I_DK)));	
 
#assert BRP() |= ([](Sin.1 -> []<>(Sout.I_OK)));
