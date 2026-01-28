module SpectatorSelector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [1:0] people_type [0:15],
    input wire [31:0] people_influence [0:15],
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_LOAD = 4'd1;
    localparam [3:0] S_SORT_00 = 4'd2;
    localparam [3:0] S_SORT_01 = 4'd3;
    localparam [3:0] S_SORT_10 = 4'd4;
    localparam [3:0] S_SORT_11 = 4'd5;
    localparam [3:0] S_TAKE_11 = 4'd6;
    localparam [3:0] S_PAIR = 4'd7;
    localparam [3:0] S_FILL_REMAIN = 4'd8;
    localparam [3:0] S_VALIDATE = 4'd9;
    localparam [3:0] S_OUTPUT = 4'd10;
    localparam [3:0] S_DONE = 4'd11;
    
    // Registers
    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd120;
    
    // FIFO storage
    reg [31:0] fifo_00 [0:15];
    reg [31:0] fifo_01 [0:15];
    reg [31:0] fifo_10 [0:15];
    reg [31:0] fifo_11 [0:15];
    reg [3:0] count_00, count_01, count_10, count_11;
    
    // Sorting registers
    reg [3:0] sort_idx, sort_idx2;
    reg [31:0] temp_val;
    
    // Accumulators
    reg [31:0] total_influence; // Q16.16 format
    reg [7:0] a_support, b_support, m_total;
    reg [7:0] take_count;
    reg [7:0] paired_count;
    
    // Selection control
    reg [3:0] idx_00, idx_01, idx_10, idx_11;
    reg [31:0] best_val;
    reg [3:0] best_cat;
    reg [3:0] pairs_to_make;
    reg [3:0] remaining_to_fill;
    
    integer i;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            cycle_count <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;
            total_influence <= 32'd0;
            a_support <= 8'd0;
            b_support <= 8'd0;
            m_total <= 8'd0;
            count_00 <= 4'd0;
            count_01 <= 4'd0;
            count_10 <= 4'd0;
            count_11 <= 4'd0;
            idx_00 <= 4'd0;
            idx_01 <= 4'd0;
            idx_10 <= 4'd0;
            idx_11 <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                fifo_00[i] <= 32'd0;
                fifo_01[i] <= 32'd0;
                fifo_10[i] <= 32'd0;
                fifo_11[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            if (state != S_IDLE) cycle_count <= cycle_count + 8'd1;
            
            case (state)
                S_IDLE: begin
                    cycle_count <= 8'd0;
                    total_influence <= 32'd0;
                    a_support <= 8'd0;
                    b_support <= 8'd0;
                    m_total <= 8'd0;
                    count_00 <= 4'd0;
                    count_01 <= 4'd0;
                    count_10 <= 4'd0;
                    count_11 <= 4'd0;
                    idx_00 <= 4'd0;
                    idx_01 <= 4'd0;
                    idx_10 <= 4'd0;
                    idx_11 <= 4'd0;
                    done <= 1'b0;
                end
                
                S_LOAD: begin
                    if (idx_00 < N) begin
                        case (people_type[idx_00])
                            2'b00: begin
                                fifo_00[count_00] <= people_influence[idx_00];
                                count_00 <= count_00 + 4'd1;
                            end
                            2'b01: begin
                                fifo_01[count_01] <= people_influence[idx_00];
                                count_01 <= count_01 + 4'd1;
                            end
                            2'b10: begin
                                fifo_10[count_10] <= people_influence[idx_00];
                                count_10 <= count_10 + 4'd1;
                            end
                            2'b11: begin
                                fifo_11[count_11] <= people_influence[idx_00];
                                count_11 <= count_11 + 4'd1;
                            end
                        endcase
                        idx_00 <= idx_00 + 4'd1;
                    end
                end
                
                // Sorting - bitonic for each category
                S_SORT_00: begin
                    if (count_00 > 1 && sort_idx < count_00 - 1) begin
                        if (sort_idx2 < count_00 - sort_idx - 1) begin
                            if (fifo_00[sort_idx2] < fifo_00[sort_idx2 + 1]) begin
                                fifo_00[sort_idx2] <= fifo_00[sort_idx2 + 1];
                                fifo_00[sort_idx2 + 1] <= fifo_00[sort_idx2];
                            end
                            sort_idx2 <= sort_idx2 + 4'd1;
                        end else begin
                            sort_idx <= sort_idx + 4'd1;
                            sort_idx2 <= 4'd0;
                        end
                    end
                end
                
                S_SORT_01: begin
                    if (count_01 > 1 && sort_idx < count_01 - 1) begin
                        if (sort_idx2 < count_01 - sort_idx - 1) begin
                            if (fifo_01[sort_idx2] < fifo_01[sort_idx2 + 1]) begin
                                fifo_01[sort_idx2] <= fifo_01[sort_idx2 + 1];
                                fifo_01[sort_idx2 + 1] <= fifo_01[sort_idx2];
                            end
                            sort_idx2 <= sort_idx2 + 4'd1;
                        end else begin
                            sort_idx <= sort_idx + 4'd1;
                            sort_idx2 <= 4'd0;
                        end
                    end
                end
                
                S_SORT_10: begin
                    if (count_10 > 1 && sort_idx < count_10 - 1) begin
                        if (sort_idx2 < count_10 - sort_idx - 1) begin
                            if (fifo_10[sort_idx2] < fifo_10[sort_idx2 + 1]) begin
                                fifo_10[sort_idx2] <= fifo_10[sort_idx2 + 1];
                                fifo_10[sort_idx2 + 1] <= fifo_10[sort_idx2];
                            end
                            sort_idx2 <= sort_idx2 + 4'd1;
                        end else begin
                            sort_idx <= sort_idx + 4'd1;
                            sort_idx2 <= 4'd0;
                        end
                    end
                end
                
                S_SORT_11: begin
                    if (count_11 > 1 && sort_idx < count_11 - 1) begin
                        if (sort_idx2 < count_11 - sort_idx - 1) begin
                            if (fifo_11[sort_idx2] < fifo_11[sort_idx2 + 1]) begin
                                fifo_11[sort_idx2] <= fifo_11[sort_idx2 + 1];
                                fifo_11[sort_idx2 + 1] <= fifo_11[sort_idx2];
                            end
                            sort_idx2 <= sort_idx2 + 4'd1;
                        end else begin
                            sort_idx <= sort_idx + 4'd1;
                            sort_idx2 <= 4'd0;
                        end
                    end
                end
                
                S_TAKE_11: begin
                    if (idx_11 < count_11) begin
                        total_influence <= total_influence + fifo_11[idx_11];
                        a_support <= a_support + 8'd1;
                        b_support <= b_support + 8'd1;
                        m_total <= m_total + 8'd1;
                        idx_11 <= idx_11 + 4'd1;
                    end
                end
                
                S_PAIR: begin
                    if (paired_count < pairs_to_make && idx_10 < count_10 && idx_01 < count_01) begin
                        total_influence <= total_influence + fifo_10[idx_10] + fifo_01[idx_01];
                        a_support <= a_support + 8'd1;
                        b_support <= b_support + 8'd1;
                        m_total <= m_total + 8'd2;
                        idx_10 <= idx_10 + 4'd1;
                        idx_01 <= idx_01 + 4'd1;
                        paired_count <= paired_count + 8'd1;
                    end
                end
                
                S_FILL_REMAIN: begin
                    if (take_count > 8'd0) begin
                        // Find best available from remaining categories
                        best_val <= 32'd0;
                        best_cat <= 4'd0;
                        
                        if (idx_00 < count_00 && fifo_00[idx_00] > best_val) begin
                            best_val <= fifo_00[idx_00];
                            best_cat <= 4'd0;
                        end
                        if (idx_01 < count_01 && fifo_01[idx_01] > best_val) begin
                            best_val <= fifo_01[idx_01];
                            best_cat <= 4'd1;
                        end
                        if (idx_10 < count_10 && fifo_10[idx_10] > best_val) begin
                            best_val <= fifo_10[idx_10];
                            best_cat <= 4'd2;
                        end
                        if (idx_11 < count_11 && fifo_11[idx_11] > best_val) begin
                            best_val <= fifo_11[idx_11];
                            best_cat <= 4'd3;
                        end
                        
                        if (best_cat == 4'd0) begin
                            total_influence <= total_influence + best_val;
                            m_total <= m_total + 8'd1;
                            idx_00 <= idx_00 + 4'd1;
                        end else if (best_cat == 4'd1) begin
                            total_influence <= total_influence + best_val;
                            a_support <= a_support + 8'd1;
                            m_total <= m_total + 8'd1;
                            idx_01 <= idx_01 + 4'd1;
                        end else if (best_cat == 4'd2) begin
                            total_influence <= total_influence + best_val;
                            b_support <= b_support + 8'd1;
                            m_total <= m_total + 8'd1;
                            idx_10 <= idx_10 + 4'd1;
                        end else if (best_cat == 4'd3) begin
                            total_influence <= total_influence + best_val;
                            a_support <= a_support + 8'd1;
                            b_support <= b_support + 8'd1;
                            m_total <= m_total + 8'd1;
                            idx_11 <= idx_11 + 4'd1;
                        end
                        take_count <= take_count - 8'd1;
                    end
                end
                
                S_VALIDATE: begin
                    // Check constraints: 2*a >= m and 2*b >= m
                    if ((m_total > 8'd0) && ((a_support << 1) >= m_total) && ((b_support << 1) >= m_total)) begin
                        valid <= 1'b1;
                    end else begin
                        valid <= 1'b0;
                    end
                    result <= total_influence[31:16]; // Right shift by 16
                end
                
                S_OUTPUT: begin
                    done <= 1'b1;
                end
                
                S_DONE: begin
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start) next_state = S_LOAD;
            end
            S_LOAD: begin
                if (idx_00 >= N) next_state = S_SORT_00;
            end
            S_SORT_00: begin
                if (count_00 <= 1 || sort_idx >= count_00 - 1) next_state = S_SORT_01;
            end
            S_SORT_01: begin
                if (count_01 <= 1 || sort_idx >= count_01 - 1) next_state = S_SORT_10;
            end
            S_SORT_10: begin
                if (count_10 <= 1 || sort_idx >= count_10 - 1) next_state = S_SORT_11;
            end
            S_SORT_11: begin
                if (count_11 <= 1 || sort_idx >= count_11 - 1) next_state = S_TAKE_11;
            end
            S_TAKE_11: begin
                if (idx_11 >= count_11) next_state = S_PAIR;
            end
            S_PAIR: begin
                if (paired_count >= pairs_to_make || idx_10 >= count_10 || idx_01 >= count_01) next_state = S_FILL_REMAIN;
            end
            S_FILL_REMAIN: begin
                if (take_count == 8'd0) next_state = S_VALIDATE;
            end
            S_VALIDATE: begin
                next_state = S_OUTPUT;
            end
            S_OUTPUT: begin
                next_state = S_DONE;
            end
            S_DONE: begin
                next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
        
        // Timeout check
        if (cycle_count >= MAX_CYCLES) next_state = S_IDLE;
    end
    
    // Pairs to make calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pairs_to_make <= 4'd0;
            take_count <= 8'd0;
        end else if (state == S_SORT_11) begin
            if (count_10 < count_01) begin
                pairs_to_make <= count_10;
                take_count <= count_01 - count_10;
            end else begin
                pairs_to_make <= count_01;
                take_count <= count_10 - count_01;
            end
        end
    end

endmodule