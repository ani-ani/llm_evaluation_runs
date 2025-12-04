module code_match_detector(
  input clk, 
  input rst_n, 
  input start, 
  input [127:0] line_in, 
  input line_valid, 
  input fragment_end, 
  output reg [2:0] max_count, 
  output reg [255:0] filenames, 
  output reg done
);

  typedef enum logic [1:0] { IDLE, PROCESSING, DONE } state_t;
  state_t curr_state, next_state;

  // Fragment storage 
  reg [127:0] frag_filename [0:1];
  reg [127:0] frag_lines [0:1][0:3];
  reg [1:0] frag_line_count [0:1];
  reg frag_filename_stored [0:1];
  reg frag_loaded [0:1];
  reg current_frag_id;
  reg processing_code_phase;

  // Matching trackers
  reg [2:0] curr_match[0:1];
  reg [2:0] max_match[0:1];

  // Normalized line registers
  reg [127:0] normalized_line;
  reg line_empty;

  // Temporary signals
  reg [127:0] next_line;
  reg [2:0] next_match[0:1];

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      curr_state <= IDLE;
      done <= 1'b0;
      frag_loaded <= '{0,0};
      frag_filename_stored <= '{0,0};
      frag_line_count <= '{0,0};
      curr_match <= '{0,0};
      max_match <= '{0,0};
      processing_code_phase <= 1'b0;
      current_frag_id <= 1'b0;
    end
    else begin
      curr_state <= next_state;
      
      case(curr_state)
        IDLE: begin
          done <= 1'b0;
          if(start) begin
            frag_loaded <= '{0,0};
            frag_filename_stored <= '{0,0};
            frag_line_count <= '{0,0};
            curr_match <= '{0,0};
            max_match <= '{0,0};
            current_frag_id <= 1'b0;
            processing_code_phase <= 1'b0;
          end
        end
        
        PROCESSING: begin
          if(line_valid) begin
            normalized_line <= next_line;
            line_empty <= (next_line == 128'd0);
            
            if(processing_code_phase && !line_empty) begin
              curr_match <= next_match;
              for(int i=0; i<2; i++) begin
                if(next_match[i] > max_match[i])
                  max_match[i] <= next_match[i];
              end
            end
            
            // Fragment storage logic
            if(~processing_code_phase) begin
              // Store filename
              if(!frag_filename_stored[current_frag_id] && !frag_loaded[current_frag_id]) begin
                frag_filename[current_frag_id] <= line_in;
                frag_filename_stored[current_frag_id] <= 1'b1;
              end
              // Store normalized line (if fragment line)
              else if(frag_filename_stored[current_frag_id] && !frag_loaded[current_frag_id] && !line_empty) begin
                if(frag_line_count[current_frag_id] < 4) begin
                  frag_lines[current_frag_id][frag_line_count[current_frag_id]] <= next_line;
                  frag_line_count[current_frag_id] <= frag_line_count[current_frag_id] + 1;
                end
              end
            end
          end
          
          if(fragment_end) begin
            // End fragment storage phase
            if(!processing_code_phase) begin
              frag_loaded[current_frag_id] <= 1'b1;
              if(!current_frag_id) begin
                current_frag_id <= 1'b1; // Switch to next fragment
              end
              else begin
                processing_code_phase <= 1'b1; // Proceed to code comparison
              end
            end
            // End code input phase
            else begin
              // Final comparison cycle
              if(max_match[0] >= max_match[1]) 
                max_count <= max_match[0];
              else 
                max_count <= max_match[1];
              
              filenames <= {frag_filename[1], frag_filename[0]};
            end
          end
        end
        
        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

  // Combinational Logic
  always_comb begin
    // Defaults
    next_state = curr_state;
    next_line = line_in; // Simplified normalization placeholder
    next_match = curr_match;
    
    case(curr_state)
      IDLE: begin
        if(start) 
          next_state = PROCESSING;
      end
      
      PROCESSING: begin
        if(fragment_end && processing_code_phase)
          next_state = DONE;
        
        // Next match calculation
        if(processing_code_phase && line_valid) begin
          for(int i=0; i<2; i++) begin
            if(frag_loaded[i]) begin
              if(frag_line_count[i] > curr_match[i] && 
                normalized_line == frag_lines[i][curr_match[i]]) begin
                next_match[i] = curr_match[i] + 1;
              end
              else begin
                // Reset to 1 if matches first line, else 0
                next_match[i] = (normalized_line == frag_lines[i][0]) ? 3'b1 : 3'b0;
              end
            end
            else begin
              next_match[i] = 3'b0;
            end
          end
        end
      end
      
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule