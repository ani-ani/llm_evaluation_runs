module guitar_hero_max_score (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] num_notes,
    input wire [3:0] note0,
    input wire [3:0] note1,
    input wire [3:0] note2,
    input wire [3:0] note3,
    input wire [1:0] num_phrases,
    input wire [3:0] phrase0_start,
    input wire [3:0] phrase0_end,
    input wire [3:0] phrase1_start,
    input wire [3:0] phrase1_end,
    output reg [3:0] max_score,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    // Internal registers
    reg [2:0] state;
    reg [3:0] base_score;
    reg [3:0] current_max_extra;
    reg [4:0] subset_counter;
    reg [3:0] t_counter;
    reg [4:0] c_value;
    reg [3:0] covered_notes;
    reg [3:0] temp_score;
    reg phrase0_in_subset;
    reg phrase1_in_subset;
    reg overlap_detected;
    reg [3:0] note;
    reg [3:0] phrase_start;
    reg [3:0] phrase_end;
    reg [3:0] phrase_duration;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd100;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            base_score <= 4'd0;
            current_max_extra <= 4'd0;
            subset_counter <= 5'd0;
            t_counter <= 4'd0;
            c_value <= 5'd0;
            covered_notes <= 4'd0;
            temp_score <= 4'd0;
            phrase0_in_subset <= 1'b0;
            phrase1_in_subset <= 1'b0;
            overlap_detected <= 1'b0;
            note <= 4'd0;
            phrase_start <= 4'd0;
            phrase_end <= 4'd0;
            phrase_duration <= 4'd0;
            cycle_count <= 5'd0;
            max_score <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        state <= COMPUTE;
                        base_score <= num_notes;
                        current_max_extra <= 4'd0;
                        subset_counter <= 5'd0;
                        t_counter <= 4'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Determine current subset
                    phrase0_in_subset <= subset_counter[0];
                    phrase1_in_subset <= subset_counter[1];
                    
                    // Calculate C (sum of durations)
                    phrase_duration <= 4'd0;
                    if (phrase0_in_subset) begin
                        phrase_duration <= phrase0_end - phrase0_start;
                    end
                    if (phrase1_in_subset) begin
                        phrase_duration <= phrase_duration + (phrase1_end - phrase1_start);
                    end
                    c_value <= phrase_duration;
                    
                    // Check overlap for current T
                    overlap_detected <= 1'b0;
                    if (phrase0_in_subset && (t_counter < phrase0_end + 4'd1) && (t_counter + c_value > phrase0_start)) begin
                        overlap_detected <= 1'b1;
                    end
                    if (phrase1_in_subset && (t_counter < phrase1_end + 4'd1) && (t_counter + c_value > phrase1_start)) begin
                        overlap_detected <= 1'b1;
                    end
                    
                    // Count covered notes if no overlap
                    covered_notes <= 4'd0;
                    if (!overlap_detected) begin
                        if (num_notes >= 4'd1 && t_counter <= note0 && note0 < t_counter + c_value) begin
                            covered_notes <= covered_notes + 4'd1;
                        end
                        if (num_notes >= 4'd2 && t_counter <= note1 && note1 < t_counter + c_value) begin
                            covered_notes <= covered_notes + 4'd1;
                        end
                        if (num_notes >= 4'd3 && t_counter <= note2 && note2 < t_counter + c_value) begin
                            covered_notes <= covered_notes + 4'd1;
                        end
                        if (num_notes >= 4'd4 && t_counter <= note3 && note3 < t_counter + c_value) begin
                            covered_notes <= covered_notes + 4'd1;
                        end
                    end
                    
                    // Update max_extra
                    if (covered_notes > current_max_extra) begin
                        current_max_extra <= covered_notes;
                    end
                    
                    // Move to next T
                    t_counter <= t_counter + 4'd1;
                    
                    // Check if done with current subset
                    if (t_counter == 4'd16) begin
                        t_counter <= 4'd0;
                        subset_counter <= subset_counter + 5'd1;
                        
                        // Check if done with all subsets
                        if (subset_counter == 5'd4) begin
                            state <= FINISH;
                        end
                    end
                    
                    // Safety exit
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    max_score <= base_score + current_max_extra;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule