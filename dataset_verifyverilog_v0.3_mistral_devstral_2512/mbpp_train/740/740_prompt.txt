module tuple_to_dict (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] tuple_data [0:5],  // 6-element input tuple
    output reg [7:0] keys [0:2],         // Up to 3 keys
    output reg [7:0] values [0:2],       // Up to 3 values
    output reg [2:0] valid_pairs,        // Number of valid pairs (0-3)
    output reg done                      // Computation complete
);

// Parameters
parameter MAX_PAIRS = 3;
parameter TUPLE_SIZE = 6;
parameter DATA_WIDTH = 8;

// Internal state
reg [1:0] state;
reg [1:0] pair_idx;

// State definitions
localparam IDLE = 2'b00;
localparam COMPUTE = 2'b01;
localparam FINISHED = 2'b10;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all outputs and state
        state <= IDLE;
        pair_idx <= 0;
        valid_pairs <= 0;
        done <= 0;
        keys[0] <= 0; keys[1] <= 0; keys[2] <= 0;
        values[0] <= 0; values[1] <= 0; values[2] <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                pair_idx <= 0;
                valid_pairs <= 0;
                if (start) begin
                    state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (pair_idx < MAX_PAIRS) begin
                    // Process adjacent pairs: tuple[0]=key, tuple[1]=val, tuple[2]=key, etc.
                    keys[pair_idx] <= tuple_data[pair_idx * 2];
                    values[pair_idx] <= tuple_data[pair_idx * 2 + 1];
                    pair_idx <= pair_idx + 1;
                    valid_pairs <= pair_idx + 1;
                    
                    // Check if we just processed the last pair
                    if (pair_idx == MAX_PAIRS - 1) begin
                        state <= FINISHED;
                    end
                end else begin
                    state <= FINISHED;
                end
            end
            
            FINISHED: begin
                done <= 1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule