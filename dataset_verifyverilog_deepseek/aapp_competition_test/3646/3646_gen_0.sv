module frog_jump_max_distance(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [15:0] spots [0:15],
  output reg [3:0] max_distance,
  output reg done
);

  typedef enum {IDLE, PROCESSING, DONE} state_t;
  state_t state, next_state;

  reg [15:0] visited; // Visited nodes
  reg [15:0] queue; // BFS queue
  reg [3:0] current_index;
  wire [3:0] next_index;
  wire queue_empty;
  wire [15:0] valid_jumps;

  // Find first node in queue (least significant bit)
  priority_encoder pe(.in(queue), .out(next_index), .valid(|queue));

  // Control signals
  assign queue_empty = (queue == 16'b0);

  // Generate jump conditions for all possible nodes
  generate
    genvar j;
    for(j=0; j<16; j=j+1) begin : jump_check
      assign valid_jumps[j] = (j < N) && (current_index < j) && !visited[j] && 
                             ((spots[current_index] + spots[j]) == (j - current_index));
    end
  endgenerate

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_distance <= 4'b0;
      done <= 1'b0;
      visited <= 16'b0;
      queue <= 16'b0;
      current_index <= 4'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            visited <= |N ? 16'b1 : 16'b0; // Mark first node
            queue <= |N ? 16'b1 : 16'b0;
            max_distance <= 4'b0;
            current_index <= 4'b0;
            state <= PROCESSING;
          end
        end

        PROCESSING: begin
          current_index <= next_index;
          if (|queue) begin
            // Update max distance when new node visited
            if (current_index > max_distance)
              max_distance <= current_index;

            // Mark current node as processed
            queue <= queue & ~(16'b1 << current_index);

            // Add valid jumps to queue
            visited <= visited | valid_jumps;
            queue <= (queue | valid_jumps) & ~(16'b1 << current_index);
          end

          if (queue_empty) begin
            state <= DONE;
            done <= 1'b1;
          end
        end

        DONE: begin
          done <= 1'b1;
          if (!start)
            state <= IDLE;
        end
      endcase
    end
  end

  // Priority encoder submodule
  module priority_encoder(
    input [15:0] in,
    output reg [3:0] out,
    output valid
  );
    always_comb begin
      out = 4'b0;
      casez (in)
        16'b???????????????1: out = 4'd0;
        16'b??????????????10: out = 4'd1;
        16'b?????????????100: out = 4'd2;
        16'b????????????1000: out = 4'd3;
        16'b???????????10000: out = 4'd4;
        16'b??????????100000: out = 4'd5;
        16'b?????????1000000: out = 4'd6;
        16'b????????10000000: out = 4'd7;
        16'b???????100000000: out = 4'd8;
        16'b??????1000000000: out = 4'd9;
        16'b?????10000000000: out = 4'd10;
        16'b????100000000000: out = 4'd11;
        16'b???1000000000000: out = 4'd12;
        16'b??10000000000000: out = 4'd13;
        16'b?100000000000000: out = 4'd14;
        16'b1000000000000000: out = 4'd15;
      endcase
    end
    assign valid = |in;
  endmodule

endmodule