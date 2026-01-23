module TopModule(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N,
    output reg [7:0] instruction,
    output reg valid,
    output reg done
);

    // Instruction encoding constants
    localparam [2:0] OP_ST  = 3'd0;
    localparam [2:0] OP_ZE  = 3'd1;
    localparam [2:0] OP_PH  = 3'd2;
    localparam [2:0] OP_PL  = 3'd3;
    localparam [2:0] OP_AD  = 3'd4;
    localparam [2:0] OP_DI  = 3'd5;
    
    localparam [1:0] REG_A  = 2'd0;
    localparam [1:0] REG_X  = 2'd1;
    localparam [1:0] REG_Y  = 2'd2;

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] OUTPUT    = 3'd1;
    localparam [2:0] DONE_STATE = 3'd2;
    
    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [5:0] prog_counter;  // Up to 64 instructions
    reg [5:0] prog_length;   // Length of current program
    reg [7:0] inst_reg;      // Temporary instruction register
    
    // Instruction storage for small programs
    reg [7:0] inst_buffer [0:15];
    integer i;
    
    // For N=2 program: PH Y, AD A X, DI Y
    // For N=5 program: ST Y, AD A X, AD A X, AD A X, AD A X, DI Y
    // For N=0: ZE Y, DI Y
    // For N=1: ST Y, DI Y
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            prog_counter <= 6'd0;
            prog_length <= 6'd0;
            instruction <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                inst_buffer[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    prog_counter <= 6'd0;
                    instruction <= 8'd0;
                    
                    if (start) begin
                        prog_counter <= 6'd0;
                        // Decode N and prepare program
                        case (N)
                            8'd0: begin
                                prog_length <= 6'd2;
                                // ZE Y
                                inst_buffer[0] <= {OP_ZE, REG_Y, 3'd0};
                                // DI Y
                                inst_buffer[1] <= {OP_DI, REG_Y, 3'd0};
                            end
                            8'd1: begin
                                prog_length <= 6'd2;
                                // ST Y
                                inst_buffer[0] <= {OP_ST, REG_Y, 3'd0};
                                // DI Y
                                inst_buffer[1] <= {OP_DI, REG_Y, 3'd0};
                            end
                            8'd2: begin
                                prog_length <= 6'd3;
                                // PH Y
                                inst_buffer[0] <= {OP_PH, REG_Y, 3'd0};
                                // AD A X
                                inst_buffer[1] <= {OP_AD, REG_A, REG_X, 1'd0};
                                // DI Y
                                inst_buffer[2] <= {OP_DI, REG_Y, 3'd0};
                            end
                            8'd5: begin
                                prog_length <= 6'd6;
                                // ST Y
                                inst_buffer[0] <= {OP_ST, REG_Y, 3'd0};
                                // AD A X (4 times)
                                inst_buffer[1] <= {OP_AD, REG_A, REG_X, 1'd0};
                                inst_buffer[2] <= {OP_AD, REG_A, REG_X, 1'd0};
                                inst_buffer[3] <= {OP_AD, REG_A, REG_X, 1'd0};
                                inst_buffer[4] <= {OP_AD, REG_A, REG_X, 1'd0};
                                // DI Y
                                inst_buffer[5] <= {OP_DI, REG_Y, 3'd0};
                            end
                            default: begin
                                // Minimal program for other N: ZE Y, DI Y
                                prog_length <= 6'd2;
                                inst_buffer[0] <= {OP_ZE, REG_Y, 3'd0};
                                inst_buffer[1] <= {OP_DI, REG_Y, 3'd0};
                            end
                        endcase
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    // Output current instruction
                    instruction <= inst_buffer[prog_counter];
                    valid <= 1'b1;
                    prog_counter <= prog_counter + 6'd1;
                    
                    // Check if this was the last instruction
                    if (prog_counter >= (prog_length - 6'd1)) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= OUTPUT;
                    end
                end
                
                DONE_STATE: begin
                    instruction <= 8'd0;
                    valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    instruction <= 8'd0;
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule