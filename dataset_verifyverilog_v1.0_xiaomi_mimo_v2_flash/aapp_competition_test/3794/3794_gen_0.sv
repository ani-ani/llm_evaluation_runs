module gcd_split (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    output reg done,
    output reg result,
    output reg [7:0] assignment
);

    // State machine states
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] COMPUTE    = 3'd1;
    localparam [2:0] CHECK      = 3'd2;
    localparam [2:0] FINISHED   = 3'd3;
    localparam [2:0] INCREMENT  = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] mask;
    reg [7:0] gcd1, gcd2;
    reg [7:0] count1, count2;
    reg [7:0] arr_reg [0:7];
    reg [7:0] a, b;
    reg [7:0] gcd_temp_a, gcd_temp_b;
    reg [2:0] gcd_index;
    reg [2:0] loop_index;
    reg gcd_calc_done;
    reg array_loop_done;
    reg [7:0] max_mask;

    // Helper: GCD computation using Euclidean algorithm
    localparam [2:0] GCD_IDLE     = 3'd0;
    localparam [2:0] GCD_CHECK    = 3'd1;
    localparam [2:0] GCD_UPDATE   = 3'd2;
    localparam [2:0] GCD_DONE     = 3'd3;
    
    reg [2:0] gcd_state;
    reg [2:0] gcd_next_state;
    reg [7:0] gcd_a, gcd_b, gcd_result;
    reg gcd_start, gcd_done;

    // GCD Combinational Logic
    always @(*) begin
        gcd_next_state = GCD_IDLE;
        gcd_done = 1'b0;
        
        case (gcd_state)
            GCD_IDLE: begin
                if (gcd_start)
                    gcd_next_state = GCD_CHECK;
                else
                    gcd_next_state = GCD_IDLE;
            end
            
            GCD_CHECK: begin
                if (gcd_b == 8'd0)
                    gcd_next_state = GCD_DONE;
                else
                    gcd_next_state = GCD_UPDATE;
            end
            
            GCD_UPDATE: begin
                gcd_next_state = GCD_CHECK;
            end
            
            GCD_DONE: begin
                gcd_done = 1'b1;
                gcd_next_state = GCD_IDLE;
            end
            
            default: gcd_next_state = GCD_IDLE;
        endcase
    end

    // Main FSM Combinational Logic
    always @(*) begin
        next_state = state;
        gcd_start = 1'b0;
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
            end
            
            COMPUTE: begin
                gcd_start = 1'b1;
                next_state = CHECK;
            end
            
            CHECK: begin
                if (gcd_done) begin
                    if (count1 > 8'd0 && count2 > 8'd0 && gcd_result == 8'd1) begin
                        if (gcd1 == 8'd1 && gcd2 == 8'd1) begin
                            next_state = FINISHED;
                        end else begin
                            next_state = INCREMENT;
                        end
                    end else begin
                        next_state = INCREMENT;
                    end
                end else begin
                    next_state = CHECK;
                end
            end
            
            INCREMENT: begin
                if (mask == 8'd254) begin
                    next_state = FINISHED;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            FINISHED: begin
                if (!start)
                    next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            assignment <= 8'd0;
            mask <= 8'd0;
            gcd1 <= 8'd0;
            gcd2 <= 8'd0;
            count1 <= 8'd0;
            count2 <= 8'd0;
            gcd_state <= GCD_IDLE;
            gcd_a <= 8'd0;
            gcd_b <= 8'd0;
            gcd_result <= 8'd0;
            gcd_index <= 3'd0;
            loop_index <= 3'd0;
            gcd_temp_a <= 8'd0;
            gcd_temp_b <= 8'd0;
            a <= 8'd0;
            b <= 8'd0;
            gcd_calc_done <= 1'b0;
            array_loop_done <= 1'b0;
            max_mask <= 8'd254;
            for (integer i = 0; i < 8; i = i + 1) begin
                arr_reg[i] <= 8'd0;
            end
        end else begin
            // GCD FSM
            gcd_state <= gcd_next_state;
            
            case (gcd_state)
                GCD_IDLE: begin
                    if (gcd_start) begin
                        gcd_a <= a;
                        gcd_b <= b;
                    end
                end
                
                GCD_CHECK: begin
                    // Update result when done
                    if (gcd_b == 8'd0) begin
                        gcd_result <= gcd_a;
                    end
                end
                
                GCD_UPDATE: begin
                    gcd_a <= gcd_b;
                    gcd_b <= gcd_a % gcd_b;
                end
                
                GCD_DONE: begin
                    // Handled in combinational
                end
            endcase
            
            // Main FSM
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    mask <= 8'd1;
                    if (start) begin
                        // Load array
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        gcd_index <= 3'd0;
                        loop_index <= 3'd0;
                        count1 <= 8'd0;
                        count2 <= 8'd0;
                        gcd1 <= 8'd0;
                        gcd2 <= 8'd0;
                        gcd_calc_done <= 1'b0;
                        array_loop_done <= 1'b0;
                    end
                end
                
                COMPUTE: begin
                    if (!array_loop_done) begin
                        // Count and set first elements for GCD
                        if (loop_index == 3'd0) begin
                            count1 <= 8'd0;
                            count2 <= 8'd0;
                            gcd1 <= 8'd0;
                            gcd2 <= 8'd0;
                        end
                        
                        if (loop_index < 3'd8) begin
                            if (mask[loop_index]) begin
                                count1 <= count1 + 8'd1;
                                if (gcd1 == 8'd0)
                                    gcd1 <= arr_reg[loop_index];
                            end else begin
                                count2 <= count2 + 8'd1;
                                if (gcd2 == 8'd0)
                                    gcd2 <= arr_reg[loop_index];
                            end
                            loop_index <= loop_index + 3'd1;
                        end else begin
                            array_loop_done <= 1'b1;
                            gcd_index <= 3'd0;
                            a <= 8'd0;
                            b <= 8'd0;
                        end
                    end else if (!gcd_calc_done) begin
                        // Compute GCDs
                        case (gcd_index)
                            3'd0: begin
                                // Start GCD for group 1
                                if (count1 > 8'd0) begin
                                    if (count1 == 8'd1) begin
                                        gcd1 <= gcd1;
                                        gcd_index <= 3'd1;
                                    end else begin
                                        a <= gcd1;
                                        b <= 8'd0;
                                        gcd_index <= 3'd1;
                                    end
                                end else begin
                                    gcd_index <= 3'd1;
                                end
                            end
                            3'd1: begin
                                // Start GCD for group 2
                                if (count2 > 8'd0) begin
                                    if (count2 == 8'd1) begin
                                        gcd2 <= gcd2;
                                        gcd_calc_done <= 1'b1;
                                    end else begin
                                        a <= gcd2;
                                        b <= 8'd0;
                                        gcd_index <= 3'd2;
                                    end
                                end else begin
                                    gcd_calc_done <= 1'b1;
                                end
                            end
                            3'd2: begin
                                // Process remaining GCDs
                                gcd_calc_done <= 1'b1;
                            end
                        endcase
                    end
                end
                
                CHECK: begin
                    if (gcd_done && gcd_calc_done) begin
                        if (count1 > 8'd0 && count2 > 8'd0 && gcd1 == 8'd1 && gcd2 == 8'd1) begin
                            result <= 1'b1;
                            assignment <= mask;
                            done <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                    end
                end
                
                INCREMENT: begin
                    mask <= mask + 8'd1;
                    if (mask == 8'd254) begin
                        // Last mask tried
                    end
                    // Reset for next iteration
                    loop_index <= 3'd0;
                    gcd_index <= 3'd0;
                    gcd_calc_done <= 1'b0;
                    array_loop_done <= 1'b0;
                end
                
                FINISHED: begin
                    if (!start) begin
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule