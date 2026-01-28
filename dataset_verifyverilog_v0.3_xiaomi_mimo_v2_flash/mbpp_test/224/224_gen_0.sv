module bit_counter #(
    parameter DATA_WIDTH = 8,
    parameter COUNT_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] data_in,
    output reg [COUNT_WIDTH-1:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] bit_index;  // Counter for bit positions (0 to 7)
    reg [COUNT_WIDTH-1:0] count_reg;  // Accumulator for count
    reg [DATA_WIDTH-1:0] remaining_reg;  // Shift register for remaining bits

    // Cycle counter to prevent infinite loops
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd8;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= {COUNT_WIDTH{1'b0}};
            done <= 1'b0;
            bit_index <= 4'd0;
            count_reg <= {COUNT_WIDTH{1'b0}};
            remaining_reg <= {DATA_WIDTH{1'b0}};
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    bit_index <= 4'd0;
                    count_reg <= {COUNT_WIDTH{1'b0}};
                    remaining_reg <= {DATA_WIDTH{1'b0}};
                    cycle_count <= 4'd0;
                    
                    if (start) begin
                        state <= COUNTING;
                        remaining_reg <= data_in;
                    end
                end

                COUNTING: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Add LSB to count
                    if (remaining_reg[0]) begin
                        count_reg <= count_reg + {COUNT_WIDTH{1'b0}} + 1'b1;
                    end
                    
                    // Shift right by 1
                    remaining_reg <= {1'b0, remaining_reg[DATA_WIDTH-1:1]};
                    bit_index <= bit_index + 4'd1;
                    
                    // Check if all bits processed
                    if (bit_index == (DATA_WIDTH - 4'd1) || cycle_count >= (MAX_CYCLES - 4'd1)) begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    result <= count_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule