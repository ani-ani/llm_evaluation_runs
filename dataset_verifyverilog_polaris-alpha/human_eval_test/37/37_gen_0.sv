module sort_even (
    input  logic              clk,
    input  logic              rst_n,
    input  logic signed [7:0] data_in [7:0],
    input  logic              start,
    output logic signed [7:0] data_out [7:0],
    output logic              done
);

    // Internal registers
    logic [2:0]               cycle_cnt;       // 0-5
    logic                     busy;

    logic signed [7:0]        even_vals [3:0]; // extracted even indices
    logic signed [7:0]        s_stage1 [3:0];  // sort stage 1 outputs
    logic signed [7:0]        s_stage2 [3:0];  // sort stage 2 outputs
    logic signed [7:0]        s_stage3 [3:0];  // sort stage 3 outputs (final sorted even)

    // Simple min/max functions for signed compare
    function automatic logic signed [7:0] min_s8 (input logic signed [7:0] a, input logic signed [7:0] b);
        if (a <= b) min_s8 = a; else min_s8 = b;
    endfunction

    function automatic logic signed [7:0] max_s8 (input logic signed [7:0] a, input logic signed [7:0] b);
        if (a >= b) max_s8 = a; else max_s8 = b;
    endfunction

    // Sequential control and data-path
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt      <= 3'd0;
            busy           <= 1'b0;
            done           <= 1'b0;

            // Clear internal arrays and outputs
            even_vals[0]   <= '0;
            even_vals[1]   <= '0;
            even_vals[2]   <= '0;
            even_vals[3]   <= '0;

            s_stage1[0]    <= '0;
            s_stage1[1]    <= '0;
            s_stage1[2]    <= '0;
            s_stage1[3]    <= '0;

            s_stage2[0]    <= '0;
            s_stage2[1]    <= '0;
            s_stage2[2]    <= '0;
            s_stage2[3]    <= '0;

            s_stage3[0]    <= '0;
            s_stage3[1]    <= '0;
            s_stage3[2]    <= '0;
            s_stage3[3]    <= '0;

            data_out[0]    <= '0;
            data_out[1]    <= '0;
            data_out[2]    <= '0;
            data_out[3]    <= '0;
            data_out[4]    <= '0;
            data_out[5]    <= '0;
            data_out[6]    <= '0;
            data_out[7]    <= '0;
        end else begin
            // Default
            done <= 1'b0;

            if (!busy) begin
                // Idle state: wait for start
                if (start) begin
                    busy      <= 1'b1;
                    cycle_cnt <= 3'd0;
                end
            end else begin
                // Busy: advance pipeline over fixed 5 cycles
                cycle_cnt <= cycle_cnt + 3'd1;

                case (cycle_cnt)
                    3'd0: begin
                        // Cycle 1: Extract even indices from data_in
                        // Mapping note: index 0 = MSB => data_in[7], index 7 = LSB => data_in[0]
                        even_vals[0] <= data_in[7]; // index 0
                        even_vals[1] <= data_in[5]; // index 2
                        even_vals[2] <= data_in[3]; // index 4
                        even_vals[3] <= data_in[1]; // index 6
                    end

                    3'd1: begin
                        // Cycle 2: Sorting network stage 1
                        // Compare (0,1) and (2,3)
                        s_stage1[0] <= min_s8(even_vals[0], even_vals[1]);
                        s_stage1[1] <= max_s8(even_vals[0], even_vals[1]);
                        s_stage1[2] <= min_s8(even_vals[2], even_vals[3]);
                        s_stage1[3] <= max_s8(even_vals[2], even_vals[3]);
                    end

                    3'd2: begin
                        // Cycle 3: Sorting network stage 2
                        // Compare (0,2) and (1,3)
                        s_stage2[0] <= min_s8(s_stage1[0], s_stage1[2]);
                        s_stage2[2] <= max_s8(s_stage1[0], s_stage1[2]);
                        s_stage2[1] <= min_s8(s_stage1[1], s_stage1[3]);
                        s_stage2[3] <= max_s8(s_stage1[1], s_stage1[3]);
                    end

                    3'd3: begin
                        // Cycle 4: Sorting network stage 3 (final)
                        // Compare (1,2)
                        s_stage3[0] <= s_stage2[0];
                        s_stage3[3] <= s_stage2[3];
                        s_stage3[1] <= min_s8(s_stage2[1], s_stage2[2]);
                        s_stage3[2] <= max_s8(s_stage2[1], s_stage2[2]);
                    end

                    3'd4: begin
                        // Cycle 5: Merge sorted even elements back and pass through odd indices
                        // Even positions (0,2,4,6) replaced; odd remain from original data_in
                        // index 0 -> data_out[7]
                        data_out[7] <= s_stage3[0];        // even idx 0
                        data_out[6] <= data_in[6];         // odd idx 1
                        data_out[5] <= s_stage3[1];        // even idx 2
                        data_out[4] <= data_in[4];         // odd idx 3
                        data_out[3] <= s_stage3[2];        // even idx 4
                        data_out[2] <= data_in[2];         // odd idx 5
                        data_out[1] <= s_stage3[3];        // even idx 6
                        data_out[0] <= data_in[0];         // odd idx 7

                        done <= 1'b1;  // result ready after 5th cycle
                        busy <= 1'b0;  // return to idle next cycle
                    end

                    default: begin
                        // Should not be used; safeguard
                        busy <= 1'b0;
                    end
                endcase
            end
        end
    end

endmodule
