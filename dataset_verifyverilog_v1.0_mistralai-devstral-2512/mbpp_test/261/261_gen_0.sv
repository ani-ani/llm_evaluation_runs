module TupleDivider(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] tuple1 [0:3],
    input wire [7:0] tuple2 [0:3],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Division results for each element
    reg [3:0] quotient [0:3];
    
    // Division unit for each element
    reg [7:0] remainder [0:3];
    reg [7:0] divisor [0:3];
    reg [7:0] dividend [0:3];
    reg [7:0] count [0:3];
    reg [7:0] shift_reg [0:3];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            for (i = 0; i < 4; i = i + 1) begin
                quotient[i] <= 4'd0;
                remainder[i] <= 8'd0;
                divisor[i] <= 8'd0;
                dividend[i] <= 8'd0;
                count[i] <= 8'd0;
                shift_reg[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        state <= COMPUTE;
                        
                        // Initialize division units
                        for (i = 0; i < 4; i = i + 1) begin
                            dividend[i] <= tuple1[i];
                            divisor[i] <= tuple2[i];
                            remainder[i] <= 8'd0;
                            count[i] <= 8'd0;
                            shift_reg[i] <= 8'd0;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Perform division for each element
                    for (i = 0; i < 4; i = i + 1) begin
                        if (count[i] < 8'd8) begin
                            // Shift left the remainder and dividend
                            shift_reg[i] <= {remainder[i][7:1], dividend[i][7]};
                            remainder[i] <= shift_reg[i];
                            
                            // Subtract divisor if possible
                            if (remainder[i] >= divisor[i]) begin
                                remainder[i] <= remainder[i] - divisor[i];
                                dividend[i][7] <= 1'b1;
                            end else begin
                                dividend[i][7] <= 1'b0;
                            end
                            
                            // Shift dividend left
                            dividend[i] <= {dividend[i][6:0], 1'b0};
                            count[i] <= count[i] + 8'd1;
                        end
                    end
                    
                    // Check if all divisions are complete
                    reg all_done;
                    all_done = 1'b1;
                    for (i = 0; i < 4; i = i + 1) begin
                        if (count[i] < 8'd8) begin
                            all_done = 1'b0;
                        end
                    end
                    
                    if (all_done || cycle_count >= MAX_CYCLES) begin
                        // Store results
                        for (i = 0; i < 4; i = i + 1) begin
                            quotient[i] <= dividend[i][7:4];
                        end
                        
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Pack results into 16-bit output
                    result <= {quotient[3], quotient[2], quotient[1], quotient[0]};
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule