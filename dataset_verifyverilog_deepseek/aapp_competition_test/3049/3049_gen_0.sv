module sub_cipher_matcher(
  input clk,
  input rst_n,
  input start,
  input [79:0] encrypted_msg,
  input [19:0] fragment,
  output reg [4:0] count,
  output reg done
);

  typedef enum {IDLE, ITERATE, DONE} state_t;
  state_t current_state, next_state;
  
  reg [4:0] pos_counter;
  wire [4:0] frag_chars [0:3];
  wire [4:0] msg_chars [0:3];
  wire substitution_valid, valid_position;
  
  // Fragment bytes
  assign frag_chars[0] = fragment[4:0];
  assign frag_chars[1] = fragment[9:5];
  assign frag_chars[2] = fragment[14:10];
  assign frag_chars[3] = fragment[19:15];
  
  // Message segment extraction
  assign msg_chars[0] = encrypted_msg[5*pos_counter +:5];
  assign msg_chars[1] = encrypted_msg[5*(pos_counter+1) +:5];
  assign msg_chars[2] = encrypted_msg[5*(pos_counter+2) +:5];
  assign msg_chars[3] = encrypted_msg[5*(pos_counter+3) +:5];
  
  // Length validation (fragment 4 chars, message 16 chars)
  wire length_valid = 4 <= 16;
  
  // Substitution rules check
  assign substitution_valid = 
    ((frag_chars[0] == frag_chars[1]) ? (msg_chars[0] == msg_chars[1]) : 1'b1) &
    ((frag_chars[0] == frag_chars[2]) ? (msg_chars[0] == msg_chars[2]) : 1'b1) &
    ((frag_chars[0] == frag_chars[3]) ? (msg_chars[0] == msg_chars[3]) : 1'b1) &
    ((frag_chars[1] == frag_chars[2]) ? (msg_chars[1] == msg_chars[2]) : 1'b1) &
    ((frag_chars[1] == frag_chars[3]) ? (msg_chars[1] == msg_chars[3]) : 1'b1) &
    ((frag_chars[2] == frag_chars[3]) ? (msg_chars[2] == msg_chars[3]) : 1'b1) &
    ((frag_chars[0] != frag_chars[1]) ? (msg_chars[0] != msg_chars[1]) : 1'b1) &
    ((frag_chars[0] != frag_chars[2]) ? (msg_chars[0] != msg_chars[2]) : 1'b1) &
    ((frag_chars[0] != frag_chars[3]) ? (msg_chars[0] != msg_chars[3]) : 1'b1) &
    ((frag_chars[1] != frag_chars[2]) ? (msg_chars[1] != msg_chars[2]) : 1'b1) &
    ((frag_chars[1] != frag_chars[3]) ? (msg_chars[1] != msg_chars[3]) : 1'b1) &
    ((frag_chars[2] != frag_chars[3]) ? (msg_chars[2] != msg_chars[3]) : 1'b1);
  
  // Valid position check (0-12 inclusive)
  assign valid_position = (pos_counter <= 12);
  
  // FSM logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      count <= 0;
      done <= 1'b1;
      pos_counter <= 5'd16; // Initialize beyond range
    end
    else begin
      case (current_state)
        IDLE: begin
          done <= 1'b1;
          if (start) begin
            current_state <= ITERATE;
            done <= 1'b0;
            count <= 0;
            pos_counter <= 0;
          end
        end
        
        ITERATE: begin
          // Check fragment length only during first iteration
          if (pos_counter == 0) begin
            if (!length_valid) begin
              count <= 0;
              current_state <= DONE;
            end
            else if (valid_position && substitution_valid) begin
              count <= count + 1;
            end
          end
          else begin
            if (valid_position && substitution_valid) begin
              count <= count + 1;
            end
          end
          
          if (pos_counter == 15) 
            current_state <= DONE;
          else
            pos_counter <= pos_counter + 1;
        end
        
        DONE: begin
          done <= 1'b1;
          if (!start) 
            current_state <= IDLE;
        end
      endcase
    end
  end

endmodule