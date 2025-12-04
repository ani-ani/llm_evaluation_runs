module unique_substrings(
  input clk,
  input rst_n,
  input start,
  input [39:0] chars_in,
  output reg [39:0] chars_out,
  output reg valid,
  output reg done
);

  reg [2:0] freq [25:0];
  reg [4:0] sorted_chars [0:7];
  reg [4:0] interleaved [0:7];
  reg [19:0] substr [0:4];
  reg [4:0] cycle;
  reg started;
  reg invalid_mode;
  reg any_overflow;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid <= 0;
      done <= 0;
      chars_out <= 0;
      cycle <= 0;
      started <= 0;
      invalid_mode <= 0;
      for (int i=0; i<26; i++) freq[i] <= 0;
      for (int i=0; i<8; i++) sorted_chars[i] <= 0;
    end else begin
      done <= 0;
      if (start && !started) begin
        started <= 1;
        cycle <= 0;
        invalid_mode <= 0;
        any_overflow <= 0;
        chars_out <= 0;
        valid <= 0;
        for (int i=0; i<26; i++) freq[i] <= 0;
      end else if (started) begin
        case (cycle)
          0: begin
            for (int i=0; i<8; i++) begin
              automatic logic [4:0] c = chars_in[5*i +:5];
              freq[c] <= freq[c] + 1;
            end
            cycle <= cycle + 1;
          end
          1,2,3,4,5,6,7,8: begin
            cycle <= cycle + 1;
          end
          9: begin
            for (int i=0; i<26; i++) begin
              if (freq[i] > 4) any_overflow <= 1;
            end
            if (any_overflow) begin
              invalid_mode <= 1;
              valid <= 0;
              chars_out <= 0;
            end else begin
              for (int i=0; i<8; i++) begin
                sorted_chars[i] <= chars_in[5*i +:5];
              end
            end
            cycle <= cycle + 1;
          end
          10,11,12,13,14,15,16: begin /* Bubble sort */
            if (!invalid_mode) begin
              for (int i=0; i<8; i++) begin
                for (int j=0; j<7; j++) begin
                  if (sorted_chars[j] > sorted_chars[j+1]) begin
                    automatic logic [4:0] tmp = sorted_chars[j];
                    sorted_chars[j] <= sorted_chars[j+1];
                    sorted_chars[j+1] <= tmp;
                  end
                end
              end
            end
            cycle <= cycle + 1;
          end
          17: begin
            if (!invalid_mode) begin
              interleaved[0] <= sorted_chars[0];
              interleaved[1] <= sorted_chars[7];
              interleaved[2] <= sorted_chars[1];
              interleaved[3] <= sorted_chars[6];
              interleaved[4] <= sorted_chars[2];
              interleaved[5] <= sorted_chars[5];
              interleaved[6] <= sorted_chars[3];
              interleaved[7] <= sorted_chars[4];
              chars_out <= {interleaved[0], interleaved[1], interleaved[2], interleaved[3],
                           interleaved[4], interleaved[5], interleaved[6], interleaved[7]};
              substr[0] <= {sorted_chars[0], sorted_chars[7], sorted_chars[1], sorted_chars[6]};
              substr[1] <= {sorted_chars[7], sorted_chars[1], sorted_chars[6], sorted_chars[2]};
              substr[2] <= {sorted_chars[1], sorted_chars[6], sorted_chars[2], sorted_chars[5]};
              substr[3] <= {sorted_chars[6], sorted_chars[2], sorted_chars[5], sorted_chars[3]};
              substr[4] <= {sorted_chars[2], sorted_chars[5], sorted_chars[3], sorted_chars[4]};
            end
            cycle <= cycle + 1;
          end
          18: begin
            if (!invalid_mode) begin
              valid <= !(substr[0] == substr[1] || substr[0] == substr[2] || substr[0] == substr[3] || substr[0] == substr[4] ||
                         substr[1] == substr[2] || substr[1] == substr[3] || substr[1] == substr[4] ||
                         substr[2] == substr[3] || substr[2] == substr[4] ||
                         substr[3] == substr[4]);
              if (substr[0] == substr[1] || substr[0] == substr[2] || substr[0] == substr[3] || substr[0] == substr[4] ||
                  substr[1] == substr[2] || substr[1] == substr[3] || substr[1] == substr[4] ||
                  substr[2] == substr[3] || substr[2] == substr[4] ||
                  substr[3] == substr[4]) begin
                chars_out <= 0;
              end
            end
            cycle <= cycle + 1;
          end
          19: begin
            done <= 1;
            started <= 0;
          end
        endcase
      end
    end
  end
endmodule