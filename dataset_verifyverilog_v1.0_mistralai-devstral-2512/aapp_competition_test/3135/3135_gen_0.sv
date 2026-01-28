module SignedBinaryRepresentation(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [99:0] n_bin,
    output reg [199:0] res_bits,
    output reg done
);

    // State declarations
    localparam [7:0] IDLE = 8'd0;
    localparam [7:0] COMPUTE = 8'd1;
    localparam [7:0] FINISH = 8'd2;
    
    reg [7:0] state;
    reg [7:0] pos;
    reg carry;
    reg [7:0] best_count;
    reg [199:0] best_val;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos <= 8'd0;
            carry <= 1'b0;
            best_count <= 8'd0;
            best_val <= 200'd0;
            cycle_count <= 8'd0;
            res_bits <= 200'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        pos <= 8'd0;
                        carry <= 1'b0;
                        best_count <= 8'd0;
                        best_val <= 200'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // DP state machine
                    if (pos < 8'd100) begin
                        // Current bit
                        reg current_bit;
                        current_bit = n_bin[pos];
                        
                        // Try all options
                        reg [1:0] best_option;
                        reg [7:0] min_count;
                        reg [199:0] min_val;
                        reg [1:0] option;
                        
                        // Initialize with first option
                        option = 2'd0;
                        min_count = best_count + (option != 2'd0 ? 8'd1 : 8'd0);
                        min_val = {best_val[197:0], option};
                        best_option = option;
                        
                        // Try option 1
                        option = 2'd1;
                        reg new_count = best_count + (option != 2'd0 ? 8'd1 : 8'd0);
                        reg [199:0] new_val = {best_val[197:0], option};
                        if (new_count < min_count || (new_count == min_count && new_val < min_val)) begin
                            min_count = new_count;
                            min_val = new_val;
                            best_option = option;
                        end
                        
                        // Try option 2
                        option = 2'd2;
                        new_count = best_count + (option != 2'd0 ? 8'd1 : 8'd0);
                        new_val = {best_val[197:0], option};
                        if (new_count < min_count || (new_count == min_count && new_val < min_val)) begin
                            min_count = new_count;
                            min_val = new_val;
                            best_option = option;
                        end
                        
                        // Update state
                        best_count <= min_count;
                        best_val <= min_val;
                        pos <= pos + 8'd1;
                        
                        // Update carry
                        case (best_option)
                            2'd0: carry <= 1'b0;
                            2'd1: carry <= 1'b0;
                            2'd2: carry <= 1'b1;
                        endcase
                        
                    end else begin
                        state <= FINISH;
                        res_bits <= best_val;
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        res_bits <= best_val;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule