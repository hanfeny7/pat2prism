//@Model: Cambridge Ring Protocol
//@Tag: Protocol
/*@Description:
  The Cambridge Ring Protocol is a communication protocol for message passing between a Sender and a Receiver over a ring structure. 
  The Sender is responsible for sending messages or control signals to the Receiver. 
  - The Sender ensures that sequence numbers match before advancing.
  - If sequence mismatches occur, the error is raised.
  - The Sender reacts to errors or resets by transitioning to the SReset.
  The Receiver process is responsible for receiving messages or control signals from the Sender and reacts to incoming signals.
  - When the receiver is ready, it sends RDY signal to the buffer channel.
  - The Receiver ensures that sequence numbers match before advancing.
  - If sequence mismatches occur, the error is raised.
  - The Receiver can transition to the RReset state when a reset signal is received.
  And there is a buffer storing messages from the sender and the receiver and from the receiver to the sender:
  - The buffer has potential message loss.
  - Messages are removed from the buffer and sent to the other in FIFO order.
  - The buffer must have space available for new messages before accepting them.
  The protocol ensures reliable communication despite potential issues like data loss, synchronization errors, or channel faults.

*/

// size of buffer K:
#define K 3;
// loosy channels
#define LOSS 1;
// error type 0,1,2,3
#define ERROR 1;

enum { RESET, RDY, NOTRDY, DATA, NODATA }; 

#define tr 8;

channel sRESET1 0;
channel sRESET2 0;
channel rRESET1 0;
channel rRESET2 0;
channel	sRDY1 0;
channel sRDY2 0;
channel	sNOTRDY1 0;
channel sNOTRDY2 0;
channel	rDATA1 0;
channel rDATA2 0;
channel	rNODATA1 0;
channel rNODATA2 0;


/*-----------------------------------------------Sender & Receiver---------------------------------------------------------------------*/
var n = [-1,0]; 

hvar sqerror_flag = 0;

var sm_fake;

Sender() = SIdle();

SIdle() = sRESET1?0 -> rRESET1!0{ n[0] = -1 } -> SIdle() []
	      sNOTRDY1?m{sm_fake = m} -> SQI(m) []
		  sRDY1?m{sm_fake = m} -> SQA(m) []
		  rRESET1!0 -> SReset();

SQI(m) = [ m == (n[0] + 1)%4 ]sqi.0 -> SIdle() []
		 [ m != (n[0] + 1)%4 ]sqi.1{ sqerror_flag = 1 } -> Skip;
			 
SReset() = sNOTRDY1?m{sm_fake = m} -> SReset() []
		   sRDY1?m{sm_fake = m} -> SReset() []
		   sRESET1?0{ n[0] = -1 } -> SIdle();

SQA(m) = [ m == (n[0] + 1)%4 ]sqa.0{ n[0] = (n[0] + 1)%4 } -> SAdvance() []
		 [ m != (n[0] + 1)%4 ]sqa.1{ sqerror_flag = 1 } -> Skip;

SAdvance() = rNODATA1!n[0] -> SN() []
          rDATA1!n[0] -> SE();

SN() = rRESET1!0 -> SReset() []
	   sRESET1?0 -> rRESET1!0{ n[0] = -1 } -> SIdle() []
	   rDATA1!n[0] -> SE() []
	   sRDY1?m{sm_fake = m} -> SQN(m);

SQN(m) = [ ERROR == 1 && m == n[0] ]rDATA1!n[0] -> SN() []
		 [ ERROR != 1 && m == n[0] ]rNODATA1!n[0] -> SN() []
		 [ m != n[0] ]sqn{ sqerror_flag = 1 } -> Skip;

SE() = rRESET1!0 -> SReset() []
	   sRESET1?0 -> rRESET1!0{ n[0] = -1 } -> SIdle() []
	   [ ERROR == 2 ]sNOTRDY1?m{sm_fake = m} -> SQI(m) []
	   [ ERROR != 2 ]sNOTRDY1?m{sm_fake = m} -> SQE(m) []
	   sRDY1?m{sm_fake = m} -> SQE(m);

SQE(m) =  [ m == n[0] ]rDATA1!n[0] -> SE() []
		  [ m == (n[0] + 1)%4 ]sqe{ n[0] = (n[0] + 1)%4 } -> SAdvance();




hvar rqerror_flag = 0;

Receiver() = RIdle();

var rm_fake;

RIdle() = rRESET2?0 -> sRESET2!0{ n[1] = 0 } -> RIdle() []
	      rNODATA2?m{rm_fake = m} -> RQI(m) []
		  rDATA2?m{rm_fake = m} -> RQA(m) []
		  sRESET2!0 -> RReset() []
		  sRDY2!n[1] -> RE();

 
RQI(m) = [ m == n[1] ]rqi.0 -> RIdle() []
		 [ m != n[1] ]rqi.1{ rqerror_flag = 1 } -> Skip;
		 
RReset() = rDATA2?m{rm_fake = m} -> RReset() []
		   rNODATA2?m{rm_fake = m} -> RReset() []
		   rRESET2?0{ n[1] = 0 } -> RIdle();

RQA(m) = [ m == n[1] ]rqa.0{ n[1] = (n[1] + 1)%4 } -> RAdvance() []
		 [ m != n[1] ]rqa.1{ rqerror_flag = 1 } -> Skip;
		  
RAdvance() = sNOTRDY2!n[1] -> RN() []
			 sRDY2!n[1] -> RE();

RN() = sRESET2!0 -> RReset() []
	   rRESET2?0 -> sRESET2!0{ n[1] = 0 } -> RIdle() []
	   sRDY2!n[1] -> RE() []
	   rDATA2?m{rm_fake = m} -> RQN(m);

RQN(m) = ([ (m + 1)%4 == n[1] ]sNOTRDY2!n[1] -> RN()) []
	      [ (m + 1)%4 != n[1] ]rqn -> RN();
 
RE() = sRESET2!0 -> RReset() []
    rRESET2?0 -> sRESET2!0{ n[1] = 0 } -> RIdle() []
    sRDY2!n[1] -> RE() []
    rDATA2?m{rm_fake = m} -> RQE(m) []
	   rNODATA2?m{rm_fake = m} -> RQE2(m);
 
RQE(m) = ([ (m + 1)%4 == n[1] ]sRDY2!n[1] -> RE()) []
		  [ ERROR == 3 && m == n[1] ]rqe.0 -> RAdvance() [] 
		  [ ERROR != 3 && m == n[1] ]rqe.1{ n[1] = (n[1] + 1)%4 } -> RAdvance();


RQE2(m) = [ m == n[1] ]rqe2.0 -> RIdle() []
		  [ m != n[1] ]rqe2.1{ rqerror_flag = 1 } -> Skip; 



/*------------------------------------------------StoR & RtoS-----------------------------------------------------------------------------*/

var sbuf[K];
var sbuf_act = 0;

var r_fake;

StoR() = Q();
Q() =  ([ sbuf_act != K ]rRESET1?0{ sbuf[sbuf_act] = RESET; sbuf_act = sbuf_act + 1 } -> Q()) []
	   ([ sbuf_act != K ]rDATA1?r{ sbuf[sbuf_act] = DATA + tr * r ; sbuf_act = sbuf_act + 1; r_fake = r } -> Q()) []
	   ([ sbuf_act != K ]rNODATA1?r{ sbuf[sbuf_act] = NODATA + tr * r ; sbuf_act = sbuf_act + 1; r_fake = r } -> Q()) []
	   ([ LOSS != 0 && sbuf_act != 0 ]pop_front{ 
	   												var index = 0;
	   												while( index < sbuf_act - 1 )
	   												{
	   													sbuf[index] = sbuf[index+1];
	   													index = index + 1;
	   												}
	   												sbuf[index] = 0;
	   												sbuf_act = sbuf_act - 1;	   
	   	   									   } -> Q()) []	   	   									  	   	   									   
	   ([ sbuf_act != 0 && sbuf[0] == RESET]rRESET2!0{
	   		   												var index = 0;
	   														while( index < sbuf_act - 1 )
	   														{
	   															sbuf[index] = sbuf[index+1];
	   															index = index + 1;
	   														}
	   														sbuf[index] = 0;
	   														sbuf_act = sbuf_act - 1;	
													 } -> Q()) []											  
    ([ sbuf_act != 0 && (sbuf[0] % tr) == DATA ]rDATA2!(sbuf[0]/tr){
	   		   																var index = 0;
	   																		while( index < sbuf_act - 1 )
	   																		{
	   																			sbuf[index] = sbuf[index+1];
	   																			index = index + 1;
	   																		}
	   																		sbuf[index] = 0;
	   																		sbuf_act = sbuf_act - 1;
																		} -> Q()) []
       ([ sbuf_act != 0 && (sbuf[0] % tr) == NODATA ]rNODATA2!(sbuf[0]/tr){
	   		   																	var index = 0;
	   																			while( index < sbuf_act - 1 )
	   																			{
	   																				sbuf[index] = sbuf[index+1];
	   																				index = index + 1;
	   																			}
	   																			sbuf[index] = 0;
	   																			sbuf_act = sbuf_act - 1;
																			} -> Q());
														
														 														 
var rbuf[K];
var rbuf_act = 0;

var s_fake;

RtoS() = P();

P() =  ([ rbuf_act != K ]sRESET2?0{ rbuf[rbuf_act] = RESET; rbuf_act = rbuf_act + 1 } -> P()) []
	   ([ rbuf_act != K ]sRDY2?s{ rbuf[rbuf_act] = RDY + tr * s ; rbuf_act = rbuf_act + 1; s_fake = s } -> P()) []
	   ([ rbuf_act != K ]sNOTRDY2?s{ rbuf[rbuf_act] = NOTRDY + tr * s ; rbuf_act = rbuf_act + 1; s_fake = s } -> P()) []
	   ([ LOSS != 0 && rbuf_act != 0 ]pop_front{
	   												var index = 0;
	   												while( index < rbuf_act - 1 )
	   												{
	   													rbuf[index] = rbuf[index+1];
	   													index = index + 1;
	   												}
	   												rbuf[index] = 0;
	   												rbuf_act = rbuf_act - 1;	   
	   	   									   } -> P()) []
       ([ rbuf_act != 0 && rbuf[0] == RESET ]sRESET1!0{
	   		   												var index = 0;
	   														while( index < rbuf_act - 1 )
	   														{
	   																rbuf[index] = rbuf[index+1];
	   																index = index + 1;
	   														}
	   														rbuf[index] = 0;
	   														rbuf_act = rbuf_act - 1;	
														} -> P()) []											  
	   ([ rbuf_act != 0 && (rbuf[0] % tr) == RDY ]sRDY1!(rbuf[0]/tr){
																			var index = 0;
	   																		while( index < rbuf_act - 1 )
	   																		{
	   																			rbuf[index] = rbuf[index+1];
	   																			index = index + 1;
	   																		}
	   																		rbuf[index] = 0;
	   																		rbuf_act = rbuf_act - 1;
																	 } -> P()) []
	   ([ rbuf_act != 0 && (rbuf[0] % tr) == NOTRDY ]sNOTRDY1!(rbuf[0]/tr){
																				var index = 0;
	   																			while( index < rbuf_act - 1 )
	   																			{
	   																				rbuf[index] = rbuf[index+1];
	   																				index = index + 1;
	   																			}
	   																			rbuf[index] = 0;
	   																			rbuf_act = rbuf_act - 1;
																			} -> P());



/*-----------------------------------------------------------------------------------------------------------------------------*/

Cambridge() = Sender() ||| Receiver() ||| StoR() ||| RtoS();	

/*-----------------------------------------------------------------------------------------------------------------------------*/

/*@Properties:
  1. The protocol is deadlock-free
  2. Sender can get into an error state
  3. Receiver can get into an error state
*/
#assert Cambridge() deadlockfree;

#define goal_0 sqerror_flag == 1;
#assert Cambridge() reaches goal_0;

#define goal_1 rqerror_flag == 1;
#assert Cambridge() reaches goal_1;
